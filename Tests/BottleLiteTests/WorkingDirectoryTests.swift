import Foundation
import Testing

@testable import BottleLite

struct WorkingDirectoryTests {
    @Test func climbsOutOfBinFolderForGames() {
        // AssaultCube: exe in bin_win32, must run from the game root.
        let exe = URL(filePath: "/prefix/drive_c/Program Files/AssaultCube 1.3.0.2/bin_win32/ac_client.exe")
        let cwd = WineProgramRunner.workingDirectory(for: exe)
        #expect(cwd.path == "/prefix/drive_c/Program Files/AssaultCube 1.3.0.2")
    }

    @Test func climbsOutOfNestedBinariesWin64() {
        // Unreal Engine layout: Binaries/Win64.
        let exe = URL(filePath: "/prefix/drive_c/Games/MyGame/Binaries/Win64/MyGame.exe")
        let cwd = WineProgramRunner.workingDirectory(for: exe)
        #expect(cwd.path == "/prefix/drive_c/Games/MyGame")
    }

    @Test func keepsExecutableFolderWhenNotInBin() {
        let exe = URL(filePath: "/prefix/drive_c/Program Files/Notepad++/notepad++.exe")
        let cwd = WineProgramRunner.workingDirectory(for: exe)
        #expect(cwd.path == "/prefix/drive_c/Program Files/Notepad++")
    }
}
