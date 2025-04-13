- parsovat sockaddr
- benchmarking traceru (hyperfine)
- **přidat README**

## optional
- změnit main breakpoint na hardware breakpoint
- držet file descriptory
- thready
- stack unwinding
- ignorovat některé argumenty pro snapshot testy

# velké wtf momenty
- clone v libc se chová jinak než syscall
  - mění se mezi architekturami
- ptrace umožňuje načíst všechny registry naráz, ale i postupně z user region

- ptrace má možnosti zastavit na exec/fork/clone eventy, původně jsem to tak dělal, pak mi došlo že to asi nemá moc smysl
- write může být hoooodně velký, nepraktické při čtení žádaných dat
- process_vm_readv je imo zbytečně složitý syscall
- informace o procesu se dají prostě přečíst jako file, třeba memory maps
  - skip_to_main je cool funkcionalita, vyžadovala čtení memory maps, které se prostě nachází ve file v /proc lmao
- Chromium se ukončilo se SIGSEGV, což způsobilo nekonečný loop, proces byl pak neustále pokračován do SIGSEGV


# struktura práce
- úvod, popis proč a jak
  - debug symboly
- koncepty
  - operační systém
  - syscally
    - ptrace
      - tracer a tracee
    - process_vm_readv
- existující řešení
  - gdb/lldb
  - strace
  - intentrace
- použité technologie
  - rust
  - nix crate
- architektura
  - uhhh tohle bude složité, možná stojí za skip?
- implementace
  - popsání kódu
  - skip_to_main funkcionalita, vysvětlení memory maps
  - serializace
- evaluace
  - funguje to poměrně bezchybně
  - vysoká rychlost
  - funkcionalita je nic moc
- závěr, shrnutí všeho dohromady

# vyzdvihnout
- interface s iterátorem
- funkčnost s tracingem jednoho threadu
  - dobrá rozšířitelnost na původní plán
- dobrá rychlost (doložit benchmarky)

