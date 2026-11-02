// discover.js — Phigros IL2CPP 侦察
//
// 依赖 frida-il2cpp-bridge：
//   npm i -D frida-il2cpp-bridge frida-compile
//   npx frida-compile discover.js -o _discover.js
//   frida -U -f com.PigeonGames.Phigros -l _discover.js --no-pause
//
// 目的：把 Config.h 里的候选名换成真名，并确认字段偏移与 NoteType 枚举序。
// 输出四块：候选类清单 / 字段表 / 方法签名 / 运行时实时值。

import "frida-il2cpp-bridge";

const CLASS_RE = /Judge|Note|Chart|Score|Combo|Audio|Play/i;

function dumpClass(c) {
    console.log(`\n=== ${c.namespace}.${c.name} ===`);
    console.log("  [fields]");
    c.fields.forEach((f) => {
        console.log(`    ${f.type.name.padEnd(28)} ${f.name}`);
    });
    console.log("  [methods]");
    c.methods.forEach((m) => {
        if (m.parameterTypes.length > 6) return;
        const ps = m.parameterTypes.map((p) => p.name).join(", ");
        console.log(`    ${m.returnType.name} ${m.name}(${ps})`);
    });
}

Il2Cpp.perform(() => {
    const asmNames = Il2Cpp.domain.assemblies.map((a) => a.name);
    console.log("[assemblies] " + asmNames.join(", "));

    const targets = Il2Cpp.domain.assemblies
        .filter((a) => /Assembly-CSharp|Phigros/i.test(a.name))
        .map((a) => a.image);

    const hits = [];
    targets.forEach((img) => {
        img.classes.forEach((c) => {
            if (CLASS_RE.test(c.name)) hits.push(c);
        });
    });

    console.log(`[hit] ${hits.length} classes`);
    hits.forEach(dumpClass);

    // ---- 枚举 NoteType（若存在）把序号打出来 ----
    targets.forEach((img) => {
        const en = img.tryClass("Assets.Scripts.InGame.Notes.NoteType") ||
                   img.tryClass("NoteType");
        if (en) {
            console.log(`\n[enum] ${en.namespace}.${en.name}`);
            en.fields.forEach((f) => {
                if (!f.isLiteral) return;
                console.log(`    ${f.name} = ${f.value}`);
            });
        }
    });

    // ---- 运行时：找实例，每秒打印时间/连击/音符表前几个 ----
    const mgrCandidates = [
        "Assets.Scripts.InGame.Judgement.JudgeManager",
        "Assets.Scripts.InGame.Judgement.JudgementManager",
        "Assets.Scripts.InGame.Notes.NoteManager",
        "JudgeManager",
    ];

    let mgrClass = null;
    for (const n of mgrCandidates) {
        for (const img of targets) {
            const c = img.tryClass(n);
            if (c) { mgrClass = c; break; }
        }
        if (mgrClass) break;
    }
    if (!mgrClass) {
        console.log("[!] 没找到管理器类，看上面 hits 里的类名手动指定");
        return;
    }
    console.log(`\n[manager] ${mgrClass.namespace}.${mgrClass.name}`);

    const inst = mgrClass.tryValue();
    if (!inst) { console.log("[!] 管理器暂无实例（先进一局再跑）"); return; }
    console.log(inst);

    const timeField = mgrClass.fields.find((f) => /^(time|currentTime|musicTime|songTime|audioTime)$/i.test(f.name));
    const listField = mgrClass.fields.find((f) => /note/i.test(f.name) && /List|Array/.test(f.type.name));
    console.log(`[pick] time=${timeField?.name} list=${listField?.name}`);

    setInterval(() => {
        try {
            const i = mgrClass.tryValue();
            if (!i) return;
            const t = timeField ? i.field(timeField.name).value : "?";
            const l = listField ? i.field(listField.name).value : null;
            let head = "";
            if (l) {
                const arr = [...l];
                head = arr.slice(0, 3).map((n) => {
                    const tf = n.class.fields.find((f) => /^(time|startTime|hitTime)$/i.test(f.name));
                    const v = tf ? n.field(tf.name).value : "?";
                    return `t=${v}`;
                }).join(" ");
            }
            console.log(`now=${t} ${head}`);
        } catch (e) { /* 场景切换瞬间会抛，忽略 */ }
    }, 1000);
});
