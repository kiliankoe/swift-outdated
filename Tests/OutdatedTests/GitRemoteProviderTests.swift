import Testing
@testable import Outdated

@Suite("Git Remote Provider Tests")
struct GitRemoteProviderTests {

    init() {
        initializeTestLogging()
    }

    @Test("A bare environment gets the non-interactive git/ssh switches")
    func addsNonInteractiveSwitches() {
        let env = nonInteractiveGitEnvironment(base: [:])
        #expect(env["GIT_TERMINAL_PROMPT"] == "0")
        #expect(env["GIT_SSH_COMMAND"] == "ssh -oBatchMode=yes")
    }

    @Test("An existing GIT_SSH_COMMAND is preserved and extended")
    func extendsExistingSSHCommand() {
        let env = nonInteractiveGitEnvironment(base: ["GIT_SSH_COMMAND": "ssh -i key"])
        #expect(env["GIT_SSH_COMMAND"] == "ssh -i key -oBatchMode=yes")
    }

    @Test("An ssh command already in batch mode is left unchanged")
    func leavesBatchModeUntouched() {
        let env = nonInteractiveGitEnvironment(base: ["GIT_SSH_COMMAND": "ssh -oBatchMode=yes -i key"])
        #expect(env["GIT_SSH_COMMAND"] == "ssh -oBatchMode=yes -i key")
    }

    @Test("Unrelated environment variables are preserved")
    func preservesOtherVariables() {
        let env = nonInteractiveGitEnvironment(base: ["PATH": "/usr/bin"])
        #expect(env["PATH"] == "/usr/bin")
    }

    @Test("Auth-shaped failures produce a hint")
    func authFailuresProduceHint() {
        // #30: private HTTPS repo with prompts disabled.
        #expect(gitAuthHint(stderr: "fatal: could not read Username for 'https://github.com': terminal prompts disabled") != nil)
        // #17: password-protected SSH key.
        #expect(gitAuthHint(stderr: "git@github.com: Permission denied (publickey).") != nil)
        #expect(gitAuthHint(stderr: "Host key verification failed.") != nil)
    }

    @Test("Unrelated failures produce no hint")
    func unrelatedFailuresProduceNoHint() {
        #expect(gitAuthHint(stderr: "fatal: repository not found") == nil)
    }
}
