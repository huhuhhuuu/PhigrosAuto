#import "IL2CPP.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <stdio.h>
#import <stdarg.h>

// ---------------- 符号表 ----------------
typedef void *(*t_domain_get)(void);
typedef void **(*t_domain_get_assemblies)(void *domain, size_t *size);
typedef void *(*t_assembly_get_image)(void *assembly);
typedef void *(*t_class_from_name)(void *image, const char *ns, const char *name);
typedef void *(*t_class_get_field_from_name)(void *klass, const char *name);
typedef size_t (*t_field_get_offset)(void *field);
typedef void (*t_field_static_get_value)(void *field, void *value);
typedef void *(*t_field_get_type)(void *field);
typedef const char *(*t_type_get_name)(void *type);
typedef void *(*t_class_get_method_from_name)(void *klass, const char *name, int argc);
typedef int (*t_method_get_param_count)(const void *method);
typedef const char *(*t_class_get_name)(void *klass);
typedef const char *(*t_class_get_namespace)(void *klass);
typedef void *(*t_class_get_type)(void *klass);
typedef void *(*t_type_get_object)(void *type);
typedef const char *(*t_image_get_name)(void *image);
// il2cpp_runtime_invoke 直接返回 Il2CppObject*（引用类型结果即对象指针）
typedef void *(*t_runtime_invoke)(void *method, void *obj, void **params, void **exc);

static t_domain_get               p_domain_get;
static t_domain_get_assemblies    p_domain_get_assemblies;
static t_assembly_get_image       p_assembly_get_image;
static t_class_from_name          p_class_from_name;
static t_class_get_field_from_name p_class_get_field_from_name;
static t_field_get_offset         p_field_get_offset;
static t_field_static_get_value   p_field_static_get_value;
static t_field_get_type           p_field_get_type;
static t_type_get_name            p_type_get_name;
static t_class_get_method_from_name p_class_get_method_from_name;
static t_method_get_param_count   p_method_get_param_count;
static t_class_get_name           p_class_get_name;
static t_class_get_namespace      p_class_get_namespace;
static t_class_get_type           p_class_get_type;
static t_type_get_object          p_type_get_object;
static t_image_get_name           p_image_get_name;
static t_runtime_invoke           p_runtime_invoke;

static BOOL gReady = NO;

#define BIND(T, n) p_##n = (T)dlsym(RTLD_DEFAULT, "il2cpp_" #n)
#define BIND2(T, n, s) p_##n = (T)dlsym(RTLD_DEFAULT, s)

// ------------------------------------------------------------
// 关键：不能只在 constructor 阶段 dlsym(RTLD_DEFAULT)。
//
// IL2CPP 的 il2cpp_* 符号属于 UnityFramework 这个 dylib，而插件注入时
// 游戏 main() 还没跑到 dlopen(UnityFramework)，此时全局符号表里根本没有
// 这些符号，dlsym 一律返回 NULL。表现就是"插件像没装一样"。
//
// 所以这里三级兜底，每一级都试：
//   1) RTLD_DEFAULT             —— 框架已加载时最快
//   2) 遍历已加载镜像，按路径找 UnityFramework 的 handle
//   3) 显式 dlopen 一次（幂等，已加载则返回同一 handle）
// ------------------------------------------------------------

static void *PHFindUnityFramework(void) {
    // 2) 已加载镜像里按名字找
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "UnityFramework")) {
            return dlopen(name, RTLD_LAZY | RTLD_NOLOAD);
        }
    }
    // 3) 按可执行文件同级路径显式打开
    static const char *cands[] = {
        "@executable_path/Frameworks/UnityFramework.framework/UnityFramework",
        "@loader_path/Frameworks/UnityFramework.framework/UnityFramework",
        NULL
    };
    for (int i = 0; cands[i]; i++) {
        void *h = dlopen(cands[i], RTLD_LAZY);
        if (h) return h;
    }
    return NULL;
}

BOOL PHL2CPPInit(void) {
    if (gReady) return YES;

    // 先试全局，不行再定位 UnityFramework
    void *uf = NULL;
    p_class_from_name = (t_class_from_name)dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    if (!p_class_from_name) {
        uf = PHFindUnityFramework();
    }

    // 用哪个 handle 取符号：优先 UnityFramework，退化到全局
    void *h = uf ? uf : RTLD_DEFAULT;
#define BIND_H(T, n) p_##n = (T)dlsym(h, "il2cpp_" #n)

    BIND_H(t_domain_get, domain_get);
    BIND_H(t_domain_get_assemblies, domain_get_assemblies);
    BIND_H(t_assembly_get_image, assembly_get_image);
    BIND_H(t_class_from_name, class_from_name);
    BIND_H(t_class_get_field_from_name, class_get_field_from_name);
    BIND_H(t_field_get_offset, field_get_offset);
    BIND_H(t_field_static_get_value, field_static_get_value);
    BIND_H(t_field_get_type, field_get_type);
    BIND_H(t_type_get_name, type_get_name);
    BIND_H(t_class_get_method_from_name, class_get_method_from_name);
    BIND_H(t_method_get_param_count, method_get_param_count);
    BIND_H(t_class_get_name, class_get_name);
    BIND_H(t_class_get_namespace, class_get_namespace);
    BIND_H(t_class_get_type, class_get_type);
    BIND_H(t_type_get_object, type_get_object);
    BIND_H(t_image_get_name, image_get_name);
    BIND_H(t_runtime_invoke, runtime_invoke);
#undef BIND_H

    // 少数版本不带 il2cpp_ 前缀的导出名，兜底再试一次
    if (!p_class_from_name) p_class_from_name = (t_class_from_name)dlsym(h, "class_from_name");
    if (!p_runtime_invoke)  p_runtime_invoke  = (t_runtime_invoke)dlsym(h, "runtime_invoke");

    gReady = (p_domain_get && p_domain_get_assemblies && p_assembly_get_image &&
              p_class_from_name && p_class_get_field_from_name && p_field_get_offset);
    return gReady;
}

// 供上层打印诊断：当前 dlsym 环境是否已经能看到 UnityFramework
const char *PHL2CPPDiagnose(void) {
    static char buf[256];
    void *uf = PHFindUnityFramework();
    uint32_t count = _dyld_image_count();
    int unityImgs = 0;
    for (uint32_t i = 0; i < count; i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "UnityFramework")) unityImgs++;
    }
    snprintf(buf, sizeof(buf),
             "images=%u unityImages=%d ufHandle=%s ready=%d",
             count, unityImgs, uf ? "yes" : "no", gReady ? 1 : 0);
    return buf;
}

void *PHImageByName(const char *assemblyName) {
    if (!gReady) return NULL;
    void *domain = p_domain_get();
    if (!domain) return NULL;
    size_t count = 0;
    void **asmList = p_domain_get_assemblies(domain, &count);
    if (!asmList) return NULL;

    // 目标名可能带或不带 .dll 后缀
    char withDll[128] = {0};
    snprintf(withDll, sizeof(withDll), "%s.dll", assemblyName);

    for (size_t i = 0; i < count; i++) {
        void *img = p_assembly_get_image(asmList[i]);
        if (!img || !p_image_get_name) continue;
        const char *nm = p_image_get_name(img);
        if (!nm) continue;
        if (strcmp(nm, assemblyName) == 0 || strcmp(nm, withDll) == 0) return img;
    }
    return NULL;
}

void *PHFindClass(const char *ns, const char *name) {
    if (!gReady) return NULL;
    void *domain = p_domain_get();
    if (!domain) return NULL;
    size_t count = 0;
    void **asmList = p_domain_get_assemblies(domain, &count);
    if (!asmList) return NULL;

    for (size_t i = 0; i < count; i++) {
        void *img = p_assembly_get_image(asmList[i]);
        if (!img) continue;
        // 空命名空间优先按用户给的 ns 走，同时也试一次 ""（C# 全局命名空间）
        void *k = p_class_from_name(img, (ns && ns[0]) ? ns : "", name);
        if (!k && ns && ns[0]) k = p_class_from_name(img, "", name);
        if (k) return k;
    }
    return NULL;
}

int PHFieldOffset(void *klass, const char *field) {
    if (!gReady || !klass || !field) return -1;
    void *f = p_class_get_field_from_name(klass, field);
    if (!f) return -1;
    return (int)p_field_get_offset(f);
}

void *PHStaticFieldValue(void *klass, const char *field) {
    if (!gReady || !klass || !field) return NULL;
    void *f = p_class_get_field_from_name(klass, field);
    if (!f) return NULL;
    void *out = NULL;
    p_field_static_get_value(f, &out);
    return out;
}

// 字段的托管类型名，用来权威区分 System.Single / System.Double，
// 比"读出来看值合不合理"可靠——float 位型按 double 读会得到近零 denormal。
const char *PHFieldTypeName(void *klass, const char *field) {
    if (!gReady || !klass || !field || !p_field_get_type || !p_type_get_name) return NULL;
    void *f = p_class_get_field_from_name(klass, field);
    if (!f) return NULL;
    void *t = p_field_get_type(f);
    if (!t) return NULL;
    return p_type_get_name(t);
}

void *PHMethodPtr(void *klass, const char *name, int argc) {
    if (!gReady || !klass || !name) return NULL;
    for (int n = argc; n <= argc + 6; n++) {   // argc 猜错时向后放宽
        void *m = p_class_get_method_from_name(klass, name, n);
        if (m) {
            if (p_method_get_param_count && p_method_get_param_count(m) != n) continue;
            return *(void **)m;                // MethodInfo 首字段即 methodPointer
        }
    }
    return NULL;
}

int PHMethodParamCount(void *klass, const char *name) {
    if (!gReady || !klass || !name) return -1;
    for (int n = 0; n <= 8; n++) {
        void *m = p_class_get_method_from_name(klass, name, n);
        if (m && p_method_get_param_count) return p_method_get_param_count(m);
    }
    return -1;
}

void *PHObjectFindByType(void *klass) {
    if (!gReady || !klass || !p_class_get_type || !p_type_get_object || !p_runtime_invoke) return NULL;

    void *objClass = PHFindClass("UnityEngine", "Object");
    if (!objClass) return NULL;
    void *m = p_class_get_method_from_name(objClass, "FindObjectOfType", 1);
    if (!m) m = p_class_get_method_from_name(objClass, "FindFirstObjectByType", 1);
    if (!m) return NULL;

    void *typeObj = p_type_get_object(p_class_get_type(klass));
    if (!typeObj) return NULL;

    void *exc = NULL;
    void *params[1] = { typeObj };
    void *ret = p_runtime_invoke(m, NULL, params, &exc);
    if (exc) return NULL;
    return ret;      // 引用类型返回值即 Il2CppObject*
}

void *PHClassOfObject(void *obj) {
    return obj ? PH_OBJ_KLASS(obj) : NULL;
}

const char *PHClassNameOf(void *klass) {
    if (!gReady || !klass || !p_class_get_name) return "";
    return p_class_get_name(klass);
}

const char *PHClassNamespaceOf(void *klass) {
    if (!gReady || !klass || !p_class_get_namespace) return "";
    return p_class_get_namespace(klass);
}
