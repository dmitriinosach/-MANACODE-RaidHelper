local _, ns = ...
ns.news = {
    after = "1.11.0",
    rows = {
        { spell = 53760, text = "news.flask.kits" },
        { art = "raid", text = "news.flask.roles" },
        { spell = 53908, text = "news.flask.pick" },
        { art = "log", text = "news.flask.log" },
        { art = "settings", text = "news.flask.trade" },
        { tex = "Interface\\Icons\\INV_Misc_Key_03", text = "news.tips" },
        { spell = 42846, text = "news.iso.chan" },
    },
    steps = {
        { where = "shell", spot = "set.flasks", title = "news.step.flasks", text = "news.step.flasks.text" },
        { where = "shell", spot = "set.kits", title = "news.step.kits", text = "news.step.kits.text" },
        { where = "shell", spot = "set.trade", title = "news.step.trade", text = "news.step.trade.text" },
        { where = "iso", spot = "iso.casts", title = "news.step.casts", text = "news.step.casts.text" },
    },
}
