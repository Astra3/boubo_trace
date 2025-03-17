- výpis na disk
- parsovat sockaddr
- benchmarking traceru (hyperfine)

## optional
- držet file descriptory
- thready
- stack unwinding
- ignorovat některé argumenty pro snapshot testy

# velké wtf momenty
- clone v libc se chová jinak než syscall
  - mění se mezi architekturami
- ptrace má možnosti zastavit na exec/fork/clone eventy, původně jsem to tak dělal, pak mi došlo že to asi nemá moc smysl
- write může být hoooodně velký, nepraktické při čtení žádaných dat
- process_vm_readv je imo zbytečně složitý syscall
- ptrace umožňuje načíst všechny registry naráz, ale i postupně z user region
- informace o procesu se dají prostě přečíst jako file, třeba memory maps
  - skip_to_main je cool funkcionalita, vyžadovala čtení memory maps, které se prostě nachází ve file v /proc lmao
- Chromium se ukončilo se SIGSEGV, což způsobilo nekonečný loop, proces byl pak neustále pokračován do SIGSEGV


# vyzdvihnout
- interface s iterátorem
- funkčnost s tracingem jednoho threadu
- dobrá rozšířitelnost na původní plán
- dobrá rychlost (doložit benchmarky)

