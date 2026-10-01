local _, ns = ...
ns.ENC = {
    marrowgar = 36612,
    deathwhisper = 36855,
    gunship = 36948,
    saurfang = 37813,
    festergut = 36626,
    rotface = 36627,
    putricide = 36678,
    council = 37970,
    lanathel = 37955,
    valithria = 36789,
    sindragosa = 36853,
    lichking = 36597,
    leviathan = 33113,
    ignis = 33118,
    razorscale = 33186,
    xt002 = 33293,
    ironcouncil = 32867,
    kologarn = 32930,
    auriaya = 33515,
    hodir = 32845,
    thorim = 32865,
    freya = 32906,
    mimiron = 33350,
    vezax = 33271,
    yogg = 33288,
    algalon = 32871,
    halion = 39863,
    beasts = 34796,
    jaraxxus = 34780,
    champions = 34441,
    twins = 34497,
    anubarak = 34564,
}
local E = ns.ENC
ns.bosses = {
    [36612] = E.marrowgar,
    [36855] = E.deathwhisper,
    [37813] = E.saurfang,
    [36626] = E.festergut,
    [36627] = E.rotface,
    [36678] = E.putricide,
    [37970] = E.council,
    [37973] = E.council,
    [37972] = E.council,
    [37955] = E.lanathel,
    [36789] = E.valithria,
    [36853] = E.sindragosa,
    [36597] = E.lichking,
    [36939] = E.gunship,
    [36948] = E.gunship,
    [33113] = E.leviathan,
    [33118] = E.ignis,
    [33186] = E.razorscale,
    [33293] = E.xt002,
    [33329] = E.xt002,
    [32867] = E.ironcouncil,
    [32927] = E.ironcouncil,
    [32857] = E.ironcouncil,
    [32930] = E.kologarn,
    [32933] = E.kologarn,
    [32934] = E.kologarn,
    [33515] = E.auriaya,
    [34014] = E.auriaya,
    [34035] = E.auriaya,
    [32845] = E.hodir,
    [32865] = E.thorim,
    [32906] = E.freya,
    [33350] = E.mimiron,
    [33432] = E.mimiron,
    [33651] = E.mimiron,
    [33670] = E.mimiron,
    [33271] = E.vezax,
    [33524] = E.vezax,
    [33288] = E.yogg,
    [33134] = E.yogg,
    [33890] = E.yogg,
    [33136] = E.yogg,
    [32871] = E.algalon,
}
ns.trashBosses = {
    [39751] = true,
    [39747] = true,
    [39746] = true,
}
ns.bossParts = {
    [33329] = true,
    [32933] = true,
    [32934] = true,
    [34014] = true,
    [34035] = true,
    [33432] = true,
    [33524] = true,
    [33134] = true,
    [33890] = true,
    [33136] = true,
}
ns.bossWin = {
    [E.valithria] = 71196,
}
ns.bossYield = {
    [E.hodir] = true,
    [E.thorim] = true,
    [E.freya] = true,
    [E.algalon] = true,
}
ns.scriptedKills = {
    [E.lichking] = { [72350] = true },
}
ns.bossLast = {}
ns.bossSurvive = {
    [E.gunship] = true,
}
ns.bossVehicle = {
    [E.gunship] = true,
    [E.lichking] = true,
    [E.leviathan] = true,
}
ns.vehicles = {
    [36838] = E.gunship,
    [36839] = E.gunship,
}
ns.fullRegistry = {
    IcecrownCitadel = true,
    Ulduar = true,
}
ns.fixates = {
    [38222] = "tl.fixate.shade",
}
