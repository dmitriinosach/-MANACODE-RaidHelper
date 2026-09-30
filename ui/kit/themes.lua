local ADDON, ns = ...
local Kit = ns.Kit or {}
ns.Kit = Kit
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local TIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local DLG_PAPER = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DLG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local PARCH = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal"
local WEAVE = "Interface\\AddOns\\" .. ADDON .. "\\lead\\art\\weave_hatch.tga"
local CHECK_UP = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECK_DOWN = "Interface\\Buttons\\UI-CheckBox-Down"
local CHECK_HL = "Interface\\Buttons\\UI-CheckBox-Highlight"
local CHECK_MARK = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECK_OFF = "Interface\\Buttons\\UI-CheckBox-Check-Disabled"
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local ACH_CAT = "Interface\\AchievementFrame\\UI-Achievement-Category-Background"
local DLG_DARK = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local DLG_GOLD = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
local ACH_WOOD = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder"
local ACH_BG = "Interface\\AchievementFrame\\UI-Achievement-AchievementBackground"
local LATTICE = "Interface\\AddOns\\" .. ADDON .. "\\lead\\art\\weave_lattice.tga"
local EDGE = { 1, 0.86, 0.42 }
local ACCENT = { 0.22, 0.72, 0.32 }
local WOOD = { 0.255, 0.205, 0.135 }
local LIGHT = { 0.93, 0.89, 0.80 }
local LIGHT2 = { 0.79, 0.72, 0.58 }
local INK = { 0.23, 0.14, 0.06 }
local TILE = { 0.72, 0.59, 0.35 }
local WHITE = { 1, 1, 1 }
local DIMMED = { 0.45, 0.45, 0.45 }
local GOLD = { 1, 0.82, 0 }
local OAK = { 0.230, 0.190, 0.130 }
local AMBER = { 0.62, 0.48, 0.18 }
local CREAM = { 0.95, 0.91, 0.82 }
local CREAM2 = { 0.82, 0.75, 0.60 }
local INSET3 = { left = 3, right = 3, top = 3, bottom = 3 }
local INSET4 = { left = 4, right = 4, top = 4, bottom = 4 }
local INSET_DLG = { left = 7, right = 8, top = 8, bottom = 7 }
local function clamp(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end
local function tone(c, k, a)
    return { clamp(c[1] * k), clamp(c[2] * k), clamp(c[3] * k), a }
end
local function rgba(c, a)
    return { c[1], c[2], c[3], a }
end
local function lift(c, top)
    local m = math.max(c[1], c[2], c[3])
    if m <= 0 then return { top, top, top } end
    return tone(c, top / m)
end
local metal = lift(WOOD, 0.82)
local dusk = lift(WOOD, 0.22)
local brass = lift(OAK, 0.82)
local umber = lift(OAK, 0.22)
Kit.themes = {}
Kit.order = { "dark", "scroll", "gold" }
Kit.DEFAULT = "dark"
Kit.themes.dark = {
    labelKey = "set.theme.dark",
    window = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = true, tileSize = 16, edgeSize = 16, insets = INSET4,
        },
        bg = { 0.03, 0.04, 0.05, 1 },
        border = { 1, 1, 1, 1 },
        pad = 0,
        decor = {},
        grip = { 1, 1, 1, 1 },
        gripTex = GRIP,
    },
    tab = {
        h = 24,
        seat = 3,
        join = 4,
        rim = 5,
        x = 10,
        fill = { tex = WHITE8, color = { 0.012, 0.015, 0.02, 1 } },
        fillHover = { tex = WHITE8, color = { 0.09, 0.10, 0.12, 1 } },
        fillOn = { tex = WHITE8, color = { 0.03, 0.04, 0.05, 1 } },
        text = { 0.62, 0.62, 0.62 },
        textHover = WHITE,
        textOn = GOLD,
        icon = { 0.70, 0.70, 0.70, 1 },
        iconHover = { 1, 1, 1, 1 },
        iconOn = { 1, 0.9, 0.55, 1 },
    },
    panel = {
        backdrop = {
            bgFile = TIP_BG, edgeFile = TIP_EDGE,
            tile = true, tileSize = 16, edgeSize = 14, insets = INSET4,
        },
        bg = { 0.06, 0.07, 0.09, 0.85 },
        border = { 0.40, 0.42, 0.48, 0.9 },
    },
    plate = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = false, edgeSize = 14, insets = INSET4,
        },
        bg = { 0.08, 0.09, 0.11, 1 },
        border = { 0.62, 0.64, 0.70, 1 },
    },
    surface = {
        page = { 0.03, 0.04, 0.05, 1 },
        bg = { 0.10, 0.12, 0.14, 0.75 },
        alt = { 1, 1, 1, 0.03 },
        line = { 1, 1, 1, 0.07 },
        grid = { 1, 1, 1, 0.09 },
        edge = { 1, 1, 1, 0.22 },
        hover = { 1, 1, 1, 0.08 },
        selected = { 1, 1, 1, 0.16 },
        head = { 0.40, 0.36, 0.30, 0.35 },
        headOn = { 0.28, 0.40, 0.54, 0.55 },
        headText = { 0.76, 0.72, 0.62 },
        headOnText = { 0.84, 0.90, 0.98 },
        panel = { 0.10, 0.12, 0.14, 0.6 },
        zebra = { 1, 1, 1, 0.025 },
        handle = { 1, 1, 1, 0.20 },
        clear = { 0, 0, 0, 0 },
        shade = { 0, 0, 0, 0.75 },
        label = { 0.94, 0.95, 0.97 },
        labelOff = { 0.60, 0.58, 0.54 },
        laneHead = { 1, 1, 1, 0.11 },
        laneHeadHover = { 1, 1, 1, 0.12 },
        laneHeadIdle = { 1, 1, 1, 0.04 },
        laneText = { 0.92, 0.94, 0.97 },
        drop = { 0.30, 0.46, 0.64, 0.70 },
        dropOn = { 0.42, 0.72, 0.98, 0.80 },
        dropRow = { 0.24, 0.34, 0.44, 0.45 },
        dropSub = { 0.46, 0.42, 0.34, 0.55 },
    },
    fx = {
        name = { 0.94, 0.95, 0.97 },
        nameOff = { 0.66, 0.69, 0.73 },
        count = { 0.60, 0.63, 0.68 },
        countOff = { 0.50, 0.53, 0.57 },
        markOn = { 0.44, 0.78, 0.48 },
        markOff = { 0.58, 0.62, 0.66 },
        trashName = { 0.72, 0.62, 0.62 },
        trashCount = { 0.56, 0.48, 0.48 },
        trashMark = { 0.85, 0.45, 0.45 },
        trashHead = { 0.90, 0.66, 0.64 },
        line = { 1, 1, 1, 0.10 },
    },
    button = {
        backdrop = {
            bgFile = TIP_BG, edgeFile = TIP_EDGE,
            tile = true, tileSize = 16, edgeSize = 12, insets = INSET3,
        },
        bg = { 0.10, 0.11, 0.13, 0.92 },
        bgHover = { 0.17, 0.18, 0.21, 0.95 },
        bgDown = { 0.06, 0.065, 0.08, 0.95 },
        bgActive = tone(ACCENT, 0.4, 0.95),
        bgOff = { 0.06, 0.06, 0.07, 0.90 },
        border = { 0.42, 0.44, 0.50, 0.9 },
        borderHover = { 0.72, 0.74, 0.80, 1 },
        borderActive = { 0.72, 0.74, 0.80, 1 },
        borderOff = { 0.26, 0.27, 0.30, 0.6 },
        glow = { 0.72, 0.74, 0.80 },
        text = { 0.86, 0.86, 0.86 },
        textHover = WHITE,
        textActive = WHITE,
        textOff = DIMMED,
    },
    check = {
        box = { tex = CHECK_UP },
        down = { tex = CHECK_DOWN },
        hover = { tex = CHECK_HL },
        mark = { tex = CHECK_MARK },
        markOff = { tex = CHECK_OFF },
        label = GOLD,
    },
    edit = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = false, edgeSize = 12, insets = INSET3,
        },
        bg = { 0.02, 0.025, 0.03, 0.9 },
        border = { 0.42, 0.44, 0.50, 1 },
        borderFocus = { 1, 0.82, 0, 1 },
        text = WHITE,
    },
    list = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = false, edgeSize = 14, insets = INSET4,
        },
        bg = { 0.06, 0.07, 0.09, 0.97 },
        border = { 0.62, 0.64, 0.70, 1 },
        head = GOLD,
    },
    row = {
        bg = { 1, 1, 1, 0 },
        bgHover = { 1, 1, 1, 0.08 },
        bgOn = { 1, 1, 1, 0.16 },
        text = WHITE,
        textDim = { 0.75, 0.75, 0.75 },
        raid = { tex = ACH_CAT, coord = { 5 / 256, 162 / 256, 4 / 32, 23.5 / 32 }, color = { 1, 1, 1, 0.9 } },
    },
    card = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = false, edgeSize = 12, insets = INSET3,
        },
        bg = { 0.07, 0.08, 0.10, 0.96 },
        border = { 0.20, 0.22, 0.26, 1 },
        borderHover = { 0.55, 0.58, 0.66, 1 },
        borderDim = { 0.16, 0.17, 0.20, 0.8 },
        sticker = { 0.04, 0.045, 0.055, 0.95 },
    },
    scroll = {
        track = { 1, 1, 1, 0.16 },
        trackIdle = { 1, 1, 1, 0.05 },
        thumb = { 0.72, 0.78, 0.86, 0.95 },
        thumbHot = { 0.96, 0.98, 1.00, 1.00 },
        mini = { 1, 1, 1, 0.08 },
        miniThumb = { 1, 0.82, 0.3, 0.7 },
    },
    slider = {
        track = { 1, 1, 1, 0.16 },
        fill = { 1, 0.82, 0.30, 0.72 },
        thumb = { 0.72, 0.78, 0.86, 1 },
        thumbHot = { 0.96, 0.98, 1.00, 1 },
        thumbOff = { 0.40, 0.40, 0.42, 1 },
    },
    nav = {
        accent = GOLD,
        group = { 0.56, 0.56, 0.56 },
    },
    tip = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = false, edgeSize = 14, insets = INSET3,
        },
        bg = { 0.05, 0.05, 0.07, 1 },
        border = { 0.55, 0.55, 0.6, 1 },
        title = WHITE,
        body = GOLD,
        dim = { 0.80, 0.80, 0.80 },
    },
    text = {
        title = GOLD,
        primary = { 0.93, 0.93, 0.93 },
        secondary = { 0.75, 0.75, 0.75 },
        muted = { 0.68, 0.68, 0.68 },
        note = { 0.565, 0.565, 0.565 },
        ink = { 0.72, 0.72, 0.72 },
        tag = { 1, 0.25, 0.2 },
        good = { 0.49, 1, 0.54 },
        bad = { 1, 0.4, 0.3 },
        warn = { 1, 0.6, 0.3 },
        accent = ACCENT,
        bright = WHITE,
        off = { 0.5, 0.5, 0.5 },
        shadow = { 0, 0, 0, 1 },
    },
    badge = {
        backdrop = { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 },
        bg = { 0.07, 0.08, 0.10, 1 },
        edge = { 0.20, 0.22, 0.26, 1 },
        hover = { 0.55, 0.58, 0.66, 1 },
        link = { 1, 0.82, 0.30, 1 },
        linkFill = { 1, 0.82, 0.30, 0.12 },
        red = { 0.95, 0.20, 0.15, 1 },
        yellow = { 0.95, 0.75, 0.15, 1 },
        green = { 0.25, 0.80, 0.30, 1 },
        detail = { 0.86, 0.72, 0.30, 1 },
        muted = { 0.6, 0.6, 0.6, 1 },
        alert = { 1, 0.48, 0.38, 1 },
        noClass = { 0.85, 0.85, 0.85, 1 },
    },
    ach = {
        bar = { 1, 1, 1, 0.55 },
        art = { 1, 1, 1, 1 },
        artOff = { 0.55, 0.55, 0.55, 1 },
        name = WHITE,
        nameOff = { 0.65, 0.65, 0.65 },
        points = WHITE,
        pointsOff = { 0.65, 0.65, 0.65 },
    },
    parse = {
        p100 = { 0.90, 0.80, 0.50 },
        p99 = { 0.89, 0.41, 0.66 },
        p95 = { 1, 0.50, 0 },
        p75 = { 0.64, 0.21, 0.93 },
        p50 = { 0, 0.44, 0.87 },
        p25 = { 0.12, 1, 0 },
        low = { 0.62, 0.62, 0.62 },
    },
    sem = {
        lane = {
            boss = { 0.74, 0.30, 0.32 },
            casts = { 0.30, 0.56, 0.80 },
            auras = { 0.62, 0.52, 0.30 },
            healed = { 0.34, 0.68, 0.46 },
            taken = { 0.80, 0.40, 0.34 },
            takenMiss = { 0.72, 0.76, 0.84 },
            hp = { 0.36, 0.70, 0.44 },
            threat = { 0.86, 0.52, 0.26 },
        },
        threat = {
            zone = { 0.90, 0.22, 0.22, 0.10 },
            line = { 0.95, 0.35, 0.30, 0.70 },
            ok = { 0.86, 0.62, 0.30, 0.85 },
            hot = { 0.95, 0.25, 0.20, 0.95 },
            below = { 0.60, 0.60, 0.64, 0.35 },
            pull = { 1, 0.20, 0.15, 1 },
            span = { 1, 1, 1, 0.85 },
            other = { 0.55, 0.55, 0.58, 0.70 },
            life = { 0.60, 0.60, 0.64, 0.30 },
        },
        dmg = { 0.70, 0.33, 0.29 },
        heal = { 0.31, 0.55, 0.36 },
        castGcd = { 0.30, 0.56, 0.80, 0.16 },
        castBar = { 0.30, 0.56, 0.80, 0.50 },
        castCut = { 0.62, 0.36, 0.52, 0.50 },
        death = { 0.90, 0.22, 0.22, 0.95 },
        deathLine = { 0.95, 0.22, 0.22, 0.55 },
        hpLow = { 0.82, 0.60, 0.28, 0.85 },
        hpOk = { 0.34, 0.66, 0.42, 0.85 },
        cursor = { 1, 0.95, 0.75, 0.55 },
        cursorDot = { 1, 0.95, 0.75, 1 },
        cursorText = { 1, 0.9, 0.6 },
        readout = { 1, 0.94, 0.72 },
        phase = { 0.55, 0.68, 0.88, 0.55 },
        phaseDim = { 0.55, 0.68, 0.88, 0.22 },
        phaseText = { 0.72, 0.80, 0.92 },
        phaseDimText = { 0.55, 0.62, 0.72 },
        phaseHead = { 0.80, 0.86, 0.95 },
        link = { 1, 0.82, 0.2, 0.95 },
        linkBand = { 1, 0.82, 0.2, 0.18 },
        stat = {
            dps = { 0.62, 0.40, 0.85 },
            hps = { 0.30, 0.56, 0.85 },
            deaths = { 0.80, 0.40, 0.34 },
            alert = { 0.95, 0.25, 0.2 },
            extra = { 0.55, 0.62, 0.95 },
        },
        map = {
            me = { 1, 0.85, 0.3, 1 },
            unit = { 0.55, 0.75, 0.95, 1 },
            dead = { 0.45, 0.45, 0.48, 0.8 },
            npc = { 0.9, 0.25, 0.25, 0.95 },
            boss = { 0, 0, 0, 0.6 },
            skull = { 0.9, 0.9, 0.9, 0.9 },
        },
        full = { 0.35, 0.78, 0.40 },
        ready = { 0.49, 1, 0.54 },
        notReady = { 1, 0.38, 0.38 },
        offline = { 0.5, 0.5, 0.5 },
        rec = { 1, 0.15, 0.15, 1 },
        win = { 0.44, 0.75, 0.45 },
        wipe = { 0.82, 0.42, 0.42 },
        pick = { 1, 0.82, 0 },
        fault = { 0.35, 0.08, 0.08 },
        enc = { 0.10, 0.11, 0.12, 0.62 },
        rep = {
            defile = { 0.45, 0.16, 0.62, 0.85 },
            shadow = { 0.55, 0.30, 0.80, 0.8 },
            frost = { 0.55, 0.82, 1, 0.85 },
            bone = { 0.90, 0.86, 0.72, 0.7 },
            ooze = { 0.45, 0.85, 0.25, 0.8 },
            cone = { 0.62, 0.86, 1, 0.75 },
            blast = { 1, 0.45, 0.15, 0.95 },
            hit = { 0.62, 0.25, 0.85, 1 },
            pact = { 0.95, 0.20, 0.25, 0.9 },
            mc = { 0.95, 0.30, 0.95, 1 },
            victim = { 1, 0.25, 0.15, 1 },
            hitbox = { 0.74, 0.30, 0.32, 0.35 },
            chase = { 0.95, 0.75, 0.35, 0.9 },
            badge = { 0, 0, 0, 0.75 },
            now = { 1, 0.82, 0, 0.18 },
            important = { 1, 0.86, 0.55 },
            focus = { 1, 0.82, 0, 0.95 },
            focusText = { 1, 0.95, 0.35 },
            drop = { 0, 0, 0, 0.55 },
            plate = { 0, 0, 0, 0.6 },
            dropSoft = { 0, 0, 0, 0.3 },
            tank = { 0.81, 0.85, 0.90, 1 },
            heal = { 0.35, 0.82, 0.48, 1 },
            dd = { 0, 0, 0, 0.55 },
            ddHp = { 0.86, 0.87, 0.89, 1 },
            side = { 0.62, 0.62, 0.62, 1 },
            tick = { 1, 1, 1, 0.28 },
            icon = { 1, 1, 1, 1 },
            gone = { 0.5, 0.5, 0.5, 1 },
            fog = { 0.35, 0.35, 0.38 },
        },
    },
    progress = {
        track = { 1, 1, 1, 0.10 },
        fill = { 0.30, 0.58, 0.90, 0.85 },
        text = WHITE,
        queue = DIMMED,
        ring = { 0, 0, 0, 0.75 },
    },
    float = {
        backdrop = {
            bgFile = WHITE8, edgeFile = TIP_EDGE,
            tile = true, tileSize = 16, edgeSize = 12, insets = INSET3,
        },
        bg = { 0.03, 0.04, 0.05, 0.9 },
        border = { 0.55, 0.55, 0.6, 1 },
        tool = { 0, 0, 0, 0.5 },
        toolHover = { 1, 1, 1, 0.25 },
    },
}
Kit.themes.scroll = {
    labelKey = "set.theme.scroll",
    window = {
        backdrop = {
            bgFile = DLG_PAPER, edgeFile = DLG_BORDER,
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 7, right = 8, top = 8, bottom = 7 },
        },
        bg = { 1, 1, 1, 1 },
        border = { 1, 1, 1, 1 },
        pad = 8,
        decor = {
            { tex = PARCH, color = { 0.74, 0.62, 0.44 }, layer = "BACKGROUND", inset = 8 },
            { kind = "backdrop", bgFile = WEAVE, tileSize = 64, color = rgba(EDGE, 0.06), inset = 8 },
        },
    },
    tab = {
        h = 28,
        seat = 6,
        join = 12,
        rim = 13,
        x = 16,
        fill = { tex = WHITE8, color = { 0.05, 0.035, 0.02, 1 } },
        fillHover = { tex = WHITE8, color = { 0.13, 0.09, 0.05, 1 } },
        fillOn = { tex = WHITE8, color = { 0.07, 0.055, 0.035, 1 } },
        text = LIGHT2,
        textHover = WHITE,
        textOn = EDGE,
        icon = rgba(LIGHT2, 1),
        iconHover = { 1, 1, 1, 1 },
        iconOn = rgba(EDGE, 1),
    },
    panel = {
        bg = { 0.10, 0.07, 0.04, 0.78 },
        border = rgba(EDGE, 0.85),
    },
    plate = {
        bg = { 0.12, 0.08, 0.04, 1 },
        border = rgba(EDGE, 1),
    },
    scroll = {
        thumb = rgba(LIGHT2, 0.95),
        thumbHot = rgba(EDGE, 1),
        miniThumb = rgba(EDGE, 0.7),
    },
    slider = {
        track = { 0, 0, 0, 0.35 },
        fill = rgba(EDGE, 0.8),
        thumb = rgba(LIGHT2, 1),
        thumbHot = rgba(EDGE, 1),
        thumbOff = { 0.45, 0.40, 0.32, 1 },
    },
    nav = {
        accent = EDGE,
        group = { 0.72, 0.65, 0.49 },
    },
    surface = {
        page = { 0.07, 0.055, 0.035, 0.96 },
        bg = { 0.12, 0.09, 0.055, 0.78 },
        panel = { 0.12, 0.09, 0.055, 0.62 },
        head = { 0.46, 0.36, 0.20, 0.40 },
        headOn = { 0.50, 0.36, 0.16, 0.62 },
        headText = { 0.86, 0.77, 0.58 },
        headOnText = LIGHT,
        label = LIGHT,
        labelOff = { 0.62, 0.56, 0.45 },
        laneText = LIGHT,
        drop = { 0.55, 0.40, 0.18, 0.70 },
        dropOn = rgba(EDGE, 0.80),
        dropRow = { 0.34, 0.26, 0.14, 0.45 },
        dropSub = { 0.46, 0.38, 0.24, 0.55 },
    },
    fx = {
        name = LIGHT,
        nameOff = { 0.70, 0.64, 0.52 },
        count = LIGHT2,
        countOff = { 0.55, 0.50, 0.40 },
        markOff = { 0.62, 0.56, 0.45 },
        line = rgba(EDGE, 0.14),
    },
    button = {
        bg = tone(dusk, 0.55, 0.92),
        bgHover = tone(dusk, 1.00, 0.95),
        bgDown = tone(dusk, 0.38, 0.95),
        bgActive = tone(ACCENT, 0.4, 0.95),
        bgOff = tone(dusk, 0.35, 0.90),
        border = rgba(tone(metal, 0.66), 0.9),
        borderHover = rgba(metal, 1),
        borderActive = rgba(metal, 1),
        borderOff = rgba(tone(metal, 0.42), 0.6),
        glow = metal,
    },
    check = {
        label = EDGE,
    },
    edit = {
        bg = { 0.05, 0.035, 0.02, 0.9 },
        border = { 0.55, 0.45, 0.30, 1 },
        borderFocus = rgba(EDGE, 1),
    },
    list = {
        bg = { 0.10, 0.07, 0.04, 0.97 },
        border = rgba(EDGE, 1),
        head = EDGE,
    },
    card = {
        bg = { 0.09, 0.06, 0.03, 0.96 },
        border = rgba(TILE, 1),
        borderHover = rgba(EDGE, 1),
        borderDim = { 0.35, 0.28, 0.16, 0.8 },
        sticker = { 0.05, 0.035, 0.02, 0.95 },
    },
    tip = {
        bg = { 0.08, 0.06, 0.04, 1 },
        border = rgba(EDGE, 0.85),
    },
    text = {
        title = EDGE,
        primary = LIGHT,
        secondary = LIGHT2,
        muted = { 0.68, 0.62, 0.51 },
        ink = INK,
    },
    badge = {
        bg = { 0.085, 0.065, 0.045, 1 },
        edge = { 0.30, 0.24, 0.15, 1 },
        hover = { 0.78, 0.64, 0.40, 1 },
    },
    progress = {
        track = { 0, 0, 0, 0.35 },
        fill = rgba(EDGE, 0.8),
        text = LIGHT,
        queue = LIGHT2,
    },
    float = {
        bg = { 0.10, 0.07, 0.04, 0.92 },
        border = rgba(EDGE, 0.85),
        toolHover = { 1, 0.86, 0.42, 0.3 },
    },
}
Kit.themes.gold = {
    labelKey = "set.theme.gold",
    window = {
        backdrop = {
            bgFile = DLG_DARK, edgeFile = ACH_WOOD,
            tile = true, tileSize = 32, edgeSize = 32, insets = INSET_DLG,
        },
        bg = { 1, 1, 1, 1 },
        border = { 1, 1, 1, 1 },
        pad = 8,
        decor = {
            { tex = ACH_BG, color = { 0.26, 0.20, 0.12 }, layer = "BACKGROUND", inset = 8 },
            { kind = "backdrop", bgFile = LATTICE, tileSize = 64, color = rgba(GOLD, 0.06), inset = 8 },
        },
    },
    tab = {
        h = 28,
        seat = 6,
        join = 12,
        rim = 13,
        x = 16,
        fill = { tex = WHITE8, color = { 0.035, 0.028, 0.012, 1 } },
        fillHover = { tex = WHITE8, color = { 0.12, 0.095, 0.035, 1 } },
        fillOn = { tex = WHITE8, color = { 0.055, 0.044, 0.022, 1 } },
        text = CREAM2,
        textHover = WHITE,
        textOn = GOLD,
        icon = rgba(CREAM2, 1),
        iconHover = { 1, 1, 1, 1 },
        iconOn = rgba(GOLD, 1),
    },
    panel = {
        backdrop = {
            bgFile = TIP_BG, edgeFile = DLG_GOLD,
            tile = true, tileSize = 16, edgeSize = 14, insets = INSET4,
        },
        bg = { 0.08, 0.06, 0.02, 0.75 },
        border = { 1, 1, 1, 1 },
    },
    plate = {
        bg = { 0.07, 0.055, 0.03, 1 },
        border = rgba(AMBER, 1),
    },
    scroll = {
        thumb = rgba(brass, 0.95),
        thumbHot = rgba(GOLD, 1),
        miniThumb = rgba(GOLD, 0.7),
    },
    slider = {
        track = { 0, 0, 0, 0.40 },
        fill = rgba(GOLD, 0.75),
        thumb = rgba(brass, 1),
        thumbHot = { 1, 0.88, 0.45, 1 },
        thumbOff = { 0.42, 0.37, 0.28, 1 },
    },
    nav = {
        accent = GOLD,
        group = { 0.70, 0.62, 0.44 },
    },
    surface = {
        page = { 0.05, 0.04, 0.022, 0.96 },
        bg = { 0.09, 0.07, 0.035, 0.80 },
        panel = { 0.09, 0.07, 0.035, 0.62 },
        head = { 0.46, 0.36, 0.12, 0.40 },
        headOn = { 0.55, 0.42, 0.10, 0.62 },
        headText = { 0.88, 0.78, 0.52 },
        headOnText = CREAM,
        label = CREAM,
        labelOff = { 0.62, 0.56, 0.42 },
        laneText = CREAM,
        drop = { 0.55, 0.42, 0.12, 0.70 },
        dropOn = rgba(GOLD, 0.80),
        dropRow = { 0.34, 0.26, 0.08, 0.45 },
        dropSub = { 0.46, 0.38, 0.20, 0.55 },
    },
    fx = {
        name = CREAM,
        nameOff = { 0.72, 0.66, 0.52 },
        count = CREAM2,
        countOff = { 0.56, 0.50, 0.38 },
        markOff = { 0.62, 0.56, 0.42 },
        line = rgba(GOLD, 0.14),
    },
    button = {
        bg = tone(umber, 0.55, 0.92),
        bgHover = tone(umber, 1.00, 0.95),
        bgDown = tone(umber, 0.38, 0.95),
        bgActive = tone(ACCENT, 0.4, 0.95),
        bgOff = tone(umber, 0.35, 0.90),
        border = rgba(tone(brass, 0.66), 0.9),
        borderHover = rgba(brass, 1),
        borderActive = rgba(brass, 1),
        borderOff = rgba(tone(brass, 0.42), 0.6),
        glow = brass,
        text = { 0.90, 0.85, 0.72 },
    },
    check = {
        label = GOLD,
    },
    edit = {
        bg = { 0.04, 0.03, 0.012, 0.9 },
        border = rgba(AMBER, 1),
        borderFocus = rgba(GOLD, 1),
    },
    list = {
        bg = { 0.07, 0.055, 0.025, 0.97 },
        border = rgba(AMBER, 1),
        head = GOLD,
    },
    card = {
        bg = tone(umber, 0.35, 0.97),
        border = rgba(AMBER, 1),
        borderHover = rgba(GOLD, 1),
        borderDim = { 0.34, 0.27, 0.10, 0.8 },
        sticker = { 0.04, 0.03, 0.015, 0.95 },
    },
    tip = {
        bg = { 0.06, 0.045, 0.02, 1 },
        border = rgba(GOLD, 0.85),
    },
    text = {
        title = GOLD,
        primary = CREAM,
        secondary = CREAM2,
        muted = { 0.70, 0.64, 0.50 },
        ink = CREAM2,
    },
    badge = {
        bg = { 0.075, 0.06, 0.035, 1 },
        edge = { 0.32, 0.25, 0.10, 1 },
        hover = { 0.92, 0.86, 0.66, 1 },
    },
    sem = {
        rep = {
            tank = { 0.89, 0.83, 0.68, 1 },
            heal = { 0.50, 0.84, 0.56, 1 },
        },
    },
    progress = {
        track = { 0, 0, 0, 0.40 },
        fill = rgba(GOLD, 0.8),
        text = CREAM,
        queue = CREAM2,
    },
    float = {
        bg = { 0.06, 0.045, 0.02, 0.92 },
        border = rgba(GOLD, 0.85),
        toolHover = { 1, 0.82, 0, 0.3 },
    },
}
local function deepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = deepCopy(v) end
    return out
end
local function isLeaf(t)
    return t[1] ~= nil or t.bgFile ~= nil or t.edgeFile ~= nil or t.tex ~= nil
end
local function inherit(t, base)
    for k, v in pairs(base) do
        local own = t[k]
        if own == nil then
            t[k] = deepCopy(v)
        elseif type(own) == "table" and type(v) == "table" and not isLeaf(own) and not isLeaf(v) then
            inherit(own, v)
        end
    end
end
local ETALON = Kit.themes[Kit.DEFAULT]
for i = 1, #Kit.order do
    local t = Kit.themes[Kit.order[i]]
    if t ~= ETALON then inherit(t, ETALON) end
end
