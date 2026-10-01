local _, ns = ...
local SANITY, INSANE, WELL, RAY, GAZE, MALADY = 63050, 63120, 64169, 63884, 64164, 63830
local VOLLEY, DOOM, APATHY, PLAGUE, POISON, DRAIN = 63038, 64157, 64156, 64153, 64152, 64160
ns.summaries[ns.ENC.yogg] = {
    badges = {
        { kind = "stack", spell = SANITY, id = SANITY, low = true, tip = "sum.b.uld.sanity" },
        { kind = "aura", spell = INSANE, grade = "red", tip = "sum.b.uld.insane" },
        { kind = "aura", spell = WELL, grade = "green", tip = "sum.b.uld.well" },
        { kind = "hit", spell = RAY, gap = 2, tip = "sum.b.uld.ray" },
        { kind = "hit", spell = GAZE, gap = 2, tip = "sum.b.uld.gaze" },
        { kind = "aura", spell = MALADY, tip = "sum.b.uld.malady" },
    },
    blocks = {
        { kind = "sanity", label = "sum.k.uld.sanity", spell = SANITY, insane = INSANE },
        { kind = "damageTo", label = "sum.k.uld.tentacles", names = { 33966, 33985, 33983 } },
        { kind = "damageTo", label = "sum.k.uld.guards", names = { 33136, 33988 } },
        { kind = "casts", label = "sum.k.uld.yoggkicks", spells = { VOLLEY, DOOM, APATHY, PLAGUE, POISON, DRAIN },
          srcs = { 33136, 33985, 33988 } },
    },
}
