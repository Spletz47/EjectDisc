#include <coreinit/bsp.h>
#include <coreinit/foreground.h>
#include <coreinit/title.h>
#include <proc_ui/procui.h>
#include <sysapp/launch.h>

#include <mocha/mocha.h>

// BSP results & permissions: https://github.com/NWPlayer123/IOSU/blob/master/ios_bsp/libraries/bsp_entity/include/bsp_entity_enum.h

// unused, alternative patch
void givePpcBspAllClientCredentials() {
    uint32_t active = 0;
    uint32_t permissions = 0;
    for (uint32_t address = 0xE60471FC; address >= 0xE6047104; address -= 8) {
        Mocha_IOSUKernelRead32(address, &active);
        // skip if not active
        if (active == 0)
            continue;
        Mocha_IOSUKernelRead32(address + 4, &permissions);
        if (permissions == 0xF00) { // BSP_PERMISSIONS_PPC_USER
            Mocha_IOSUKernelWrite32(address + 4, 0xFFFF); // BSP_PERMISSIONS_ALL
            break;
        }
    }
}

void giveEjectRequestPpcPermissions() {
    // entity & attribute struct: https://github.com/NWPlayer123/IOSU/blob/master/ios_bsp/libraries/bsp_entity/include/bsp_entity.h
    // SMC entity is at 0xE6040D94
    // SMC attributes array: 0xE6044364
    uint32_t permissions = 0;
    // +616 for 15th attribute (which is NotificationLED), +8 for permissions
    Mocha_IOSUKernelRead32(0xE6044364 + 44 + 8, &permissions);
    // by default EjectRequest has perms 0xFF (BSP_PERMISSIONS_IOS)
    Mocha_IOSUKernelWrite32(0xE6044364 + 44 + 8, permissions | 0xF00); // BSP_PERMISSIONS_PPC_USER
}

void procUiSaveCallback() {
    OSSavesDone_ReadyToRelease();
}

// copied from https://github.com/wiiu-env/AromaUpdater/blob/9be5f01ca6b00a09fcaa5f6e46ca00a429539937/source/common.h#L20
static inline bool runningFromMiiMaker() {
    return (OSGetTitleID() & 0xFFFFFFFFFFFFF0FFull) == 0x000500101004A000ull;
}

int32_t main() {
    ProcUIInit(procUiSaveCallback);

    bool quitting = false;

    Mocha_InitLibrary();
    giveEjectRequestPpcPermissions();
    uint32_t request = 1;
    bspWrite("SMC", 0, "NotificationLED", 1, &request);

    ProcUIStatus status = PROCUI_STATUS_IN_FOREGROUND;
    while ((status = ProcUIProcessMessages(TRUE)) != PROCUI_STATUS_EXITING) {
        if (status == PROCUI_STATUS_RELEASE_FOREGROUND) {
            ProcUIDrawDoneRelease();
            continue;
        } else if (status != PROCUI_STATUS_IN_FOREGROUND) {
            continue;
        }

        if (!quitting) {
            quitting = true;
            if (runningFromMiiMaker()) {
                SYSRelaunchTitle(0, 0);
            } else {
                SYSLaunchMenu();
            }
        }
    }

    Mocha_DeInitLibrary();

    ProcUIShutdown();
    return 0;
}
