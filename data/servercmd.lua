local _, ns = ...
ns.serverCmds = {
    { key = "call", label = "scmd.call", what = "scmd.call.what", cmd = ".guild call", group = true },
    { key = "vault", label = "scmd.vault", what = "scmd.vault.what", cmd = ".guild vault" },
    { key = "hall", label = "scmd.hall", what = "scmd.hall.what", cmd = ".gh tele", dismount = true },
}
ns.serverCmdGap = 1
