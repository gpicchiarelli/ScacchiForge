# Security Policy

ScacchiForge is an early-stage research project. Do not expose it to untrusted
input or to an untrusted network until this file says the relevant surface has
been reviewed.

## Supported branch

Security fixes target `main`.

## Reporting a vulnerability

Report vulnerabilities privately through GitHub Security Advisories:

<https://github.com/gpicchiarelli/ScacchiForge/security/advisories/new>

The link works only when private vulnerability reporting is enabled in the
repository settings. It is not enabled yet.

No other private channel has been chosen yet. When there is one, this file
names it.

Do not open a public issue for exploitable behavior.

Include:

- the input (the FEN string or the bytes) or the exact command;
- the commit hash and the output of `sbcl --version`;
- what happened: a crash, a hang, memory growth, or something else;
- how you confirmed it.

If the maintainer cannot reproduce a report, the reply asks for what is missing.
A report is accepted or rejected on evidence.

## In scope

- Parsing of FEN, and of any protocol or network input once it exists: input
  that crashes the process, reads or writes outside an array when safety checks
  are relaxed, or hangs.
- Resource exhaustion: input that makes memory, CPU time, stack depth or open
  connections grow past a limit the operator configured.
- The future server (Browser/WebSocket, Game Actor, Bot Scheduler, Engine Worker
  Pool, as described in the specification): message handling, session and
  identity, backpressure, and isolation between games. It is in scope from its
  first commit.
- Build and CI tooling: workflow permissions, command injection through file
  names or input, and unpinned actions.

## Out of scope

- A wrong chess result - an illegal move, a wrong perft count, a wrong
  evaluation. Use the correctness form on the issue tracker.
- Slow search or weak play. Use the performance form.
- A pruning technique that loses a move. That is a question about its
  classification tag, not a vulnerability.
- Resource use the operator asked for. A hash table configured at 64 GB uses
  64 GB.
- Vulnerabilities in SBCL, ASDF, the operating system or GitHub. Report them
  upstream.
- Attacks that already need code execution as the same user, or control of the
  machine or the build tools.
- Output of an automated scanner without a demonstration.

## Dependencies

The systems depend on SBCL and ASDF only, and on no third-party Lisp library.
Keeping it that way is a decision of the author, accepted on 2026-10-04
([ADR-0004](docs/adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md)).
