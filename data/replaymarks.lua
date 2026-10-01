local _, ns = ...
ns.replayMarks = {
    gap = 3,
    bosses = {
        [36597] = {
            { ids = { 69409, 73797, 73798, 73799 }, sub = "SPELL_CAST_SUCCESS" },
            { ids = { 72762 }, sub = "SPELL_CAST_START" },
            { ids = { 69037 }, sub = "SPELL_SUMMON", gap = 10 },
            { ids = { 68981, 74270, 74271, 74272, 72259, 74273, 74274, 74275 }, sub = "SPELL_CAST_START" },
            { ids = { 72262 }, sub = "SPELL_CAST_START" },
            { ids = { 72350 }, sub = "SPELL_CAST_START" },
            { ids = { 68980, 74325, 74326, 74327, 73654, 74295, 74296, 74297 }, sub = "SPELL_CAST_SUCCESS" },
        },
        [36853] = {
            { ids = { 70126 }, sub = "SPELL_AURA_APPLIED" },
            { ids = { 69762 }, sub = { "SPELL_CAST_SUCCESS", "SPELL_AURA_APPLIED" } },
        },
        [36627] = {
            { ids = { 69558 }, sub = "SPELL_AURA_APPLIED" },
            { ids = { 69839 }, sub = "SPELL_CAST_START" },
        },
        [36678] = {
            { ids = { 70351, 71966, 71967, 71968 }, sub = "SPELL_CAST_START" },
            { ids = { 71255 }, sub = "SPELL_CAST_SUCCESS" },
        },
        [37955] = {
            { ids = { 71726, 71727, 71728, 71729 }, sub = "SPELL_CAST_SUCCESS" },
            { ids = { 71510 }, sub = "SPELL_CAST_SUCCESS" },
            { ids = { 73070 }, sub = "SPELL_CAST_SUCCESS" },
            { ids = { 71772 }, sub = "SPELL_CAST_SUCCESS" },
        },
        [36855] = {
            { ids = { 70842 }, sub = "SPELL_AURA_REMOVED" },
            { ids = { 71289 }, sub = "SPELL_CAST_SUCCESS" },
        },
        [37813] = {
            { ids = { 72293 }, sub = "SPELL_AURA_APPLIED" },
            { ids = { 72172, 72173, 72356, 72357, 72358 }, sub = "SPELL_SUMMON", gap = 5 },
        },
        [36612] = {
            { ids = { 69076 }, sub = "SPELL_CAST_START" },
            { ids = { 69057, 70826, 72088, 72089, 73142, 73143, 73144, 73145 }, sub = "SPELL_CAST_START" },
        },
        [36626] = {
            { ids = { 69278, 71221, 69279 }, sub = { "SPELL_CAST_SUCCESS", "SPELL_AURA_APPLIED" } },
            { ids = { 69165 }, sub = "SPELL_CAST_START" },
        },
        [37970] = {
            { ids = { 70952, 70981, 70982 }, sub = "SPELL_AURA_APPLIED" },
        },
        [36789] = {
            { ids = { 71301, 71305, 72220, 72223, 72224, 72225, 71977, 71987, 72480, 72481, 72482, 72483 },
              sub = { "SPELL_SUMMON", "SPELL_CAST_SUCCESS", "SPELL_CAST_START" }, gap = 10 },
        },
    },
}
