#import <Foundation/Foundation.h>

// il2cpp 导出 API 的运行时绑定与常用查询封装。
// 说明：Unity IL2CPP 的 iOS 构建会把 il2cpp_* 系列符号导出到 UnityFramework，
// 因此进程内 dlsym(RTLD_DEFAULT, ...) 即可拿到，无需链接静态库。

BOOL   PHL2CPPInit(void);                               // 绑定符号，成功返回 YES

void  *PHImageByName(const char *assemblyName);          // "Assembly-CSharp"（不含 .dll）
void  *PHFindClass(const char *ns, const char *name);    // 全 image 扫描，命中返回 Il2CppClass*

int    PHFieldOffset(void *klass, const char *field);    // -1 表示未找到
const char *PHFieldTypeName(void *klass, const char *field); // "System.Single" / "System.Double" / ...
void  *PHStaticFieldValue(void *klass, const char *field);
void  *PHMethodPtr(void *klass, const char *name, int argc);
int    PHMethodParamCount(void *klass, const char *name); // 按名找方法并返回参数个数，-1 未找到
void  *PHObjectFindByType(void *klass);                  // UnityEngine.Object.FindObjectOfType(T)
void  *PHClassOfObject(void *obj);                       // 读对象头里的 klass
const char *PHClassNameOf(void *klass);
const char *PHClassNamespaceOf(void *klass);

// IL2CPP 对象布局常量（arm64，Unity 2019+ 稳定）
#define PH_OBJ_KLASS(o)   (*(void **)(o))
#define PH_LIST_ITEMS(l)  (*(void ***)((char *)(l) + 0x10))
#define PH_LIST_SIZE(l)   (*(int32_t *)((char *)(l) + 0x18))

static inline float  PHReadF32(void *base, int off) { return off < 0 ? 0.f : *(float *)((char *)base + off); }
static inline double PHReadF64(void *base, int off) { return off < 0 ? 0.0 : *(double *)((char *)base + off); }
static inline int32_t PHReadI32(void *base, int off) { return off < 0 ? 0 : *(int32_t *)((char *)base + off); }
static inline uint8_t PHReadU8(void *base, int off)  { return off < 0 ? 0 : *(uint8_t *)((char *)base + off); }
