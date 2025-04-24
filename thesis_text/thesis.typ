// If you wish to add a title, authors or keywords, do so here!
#let title = "Monitorování Linuxových procesů"
#let author = "Roman Táborský"
#let czechKeywords = (
  "programovací jazyk Rust",
  "systémové volání",
  "Linux kernel",
  "sledování procesů",
)
#let englishKeywords = (
  "Rust Programming Language",
  "system calls",
  "Linux kernel",
  "process monitoring",
)

// Edit this variable if you're in more nested folders, i.e. when using the template as a git submodule
#let templFolder = "thesis_template/thesis_template/"

#set document(
  title: title,
  author: (author),
  // set keywords according to your language
  keywords: czechKeywords,
)

// Imports template
// MAKE SURE YOU HAVE CALIBRI FONTS INSTALLED (or imported, if using the online version of typst)
#import templFolder + "template.typ" as temp

// Uncomment the parameter in parenthesis to disable first line indent and increase paragraph spacing. Guidelines don't mention any *correct* way, but latex template uses first line indent.
#show: temp.template.with(
  /* firstLineIndent: false */
)

#set text(
  // SET YOUR LANGUAGE HERE CORRECTLY
  // use "cs" or "en", "sk" is not fully supported by typst
  // when you're using Czech, all conjunctions get an unbreakable space appended by the template, to prevent them from displaying as last characters on the line
  lang: "cs",
  // Template uses Calibri by default (because it's very available and we optimized font sizes for it), if you want to overwrite that (guideline allows for more fonts, see links in template.typ), do it below
  // I personally recommend Carlito as sans-serif and Tex Gyre Pangella (based on Palatino)
  font: "Tex Gyre Pagella",
)

// If you want to set custom monospace font, do it here
#show raw: set text(font: "JetBrains Mono")

/*
The very first page:
Params:
1. Thesis title in Czech or English
2. Title again in the other language
3. Your full name
4. Supervisor
Optional params:
5. Type of your thesis - bachelor, bachelor-practice, master or phd, defaults to bachelor
6. Year of the thesis, defaults to current year
*/

#temp.titlePage(
  title,
  "Monitoring of Linux Processes",
  author,
  "Ing. Jakub Beránek",
)



// Thesis assignment page
// TODO doplnit zadání

#temp.assignmentHeading


#pagebreak()
/*
All of the abstracts. Abstract should take about 10 lines.
1. Czech abstract
2. English abstract
3. Czech keywords
4. English keywords
5. Acknowledgment, if any
*/
#temp.abstracts(
  [
    Tato bakalářská práce se zabývá návrhem a implementací prototypu nástroje, který sleduje programy v operačním systému Linux. Výsledný záznam je možné uložit do souboru. V textu práce jsou také popsaný základní koncepty sledování procesů a systémových volání. Práce také obsahuje evaluaci výsledné implementace a možnosti její rozšíření do budoucna.
  ],
  [
    This Bachelor's thesis discusses the design and implementation of a tool, that allows tracing programs in Linux operating system. The resulting trace can be saved in a file. This text also describes basic concepts of process tracing and system calls. This thesis also contains evaluation of the final implementation and options to expand it in the future.
  ],
  czechKeywords,
  englishKeywords,
  // If writing in Slovak, you can optionally provide keywords and abstracts in Slovak
  // slovakAbstract: [nie je to zadarmo],
  // slovakKeywords: ("kľúčové slovo 1", "kľúčové slovo 2"),
  // You can also add a quote, if you feel like it
  // and get insanely creative with it
  quote: quote(
    [
      TODO něco z nějaké malé knihy, house of leaves nebo od linuse torvaldse
    ],
    attribution: [
      eventuálně...
    ],
    block: true,
  ),
  acknowledgment: [TODO ty basic věci sem],
  // In case you need to set custom abstract spacing
  // abstractSpacing: 2.5cm,
)


// Page numbering starts with outline
#set page(numbering: "1")


// Uncomment this if you don't want chapter title in headers
// headerHeadingPage sets if a header should be shown on a page starting with header
#show: temp.headerChapters.with(headerHeadingPage: false)
#temp.listChapters()


// List of symbols and abbreviations, automatically alphabetically sorted
// you can use packages like abbr or acrostatic for this, if you want more automatic handling
#import "@preview/abbr:0.2.3"
#abbr.list(title: [Seznam použitých zkratek a symbolů])
#abbr.make(
  ("GDB", "GNU Debugger"),
  ("CPU", "Central Processing Unit"),
  ("OS", "Operating System"),
  ("PID", "Process Identifier"),
  ("FFI", "Foreign Function Interface"),
  ("API", "Application Programing Interface"),
  ("CLI", "Command Line Interface"),
  ("CPL", "Current Protection Level"),
  ("USB", "Universal Serial Bus"),
  ("UB", "Undefined Behavior"),
  ("JSON", "JavaScript Object Notation"),
  ("GP", "General Purpose"),
  ("CS", "Code Segment"),
  ("MSR", "Model Specific Register"),
)

// List of Figures
#temp.listImages


// List of Tables
#temp.listTables


// List of Source Code Listings
#temp.listSourceCodes


// Start heading numbering
#show: temp.start_heading_numbering

#let argument_list(..content) = {
  show grid.cell.where(x: 0): it => align(strong(raw(it.body.text, block: false)), it.align)
  set par(leading: .8em)
  grid(
    columns: (auto, auto),
    align: (right, left),
    gutter: 1.3em,
    ..content
  )
}

// Start of your text

// TODO delší úvod
= Úvod
Při psaní programů, ať už v jakémkoliv paradigmatu nebo jazyce, každý programátor eventuálně řeší nějaký logický problém v programu. Tyhle problémy sahají od tlačítka, které z nějakého důvodu nic nedělá, až po finančně několika miliardové chyby. Pro zabránění, pochopení a prevenci těchto problémů byla vytvořena řada nástrojů a postupů. I přes jejich nepřeberné množství je stále možné najít nějakou nevyplněnou díru, postup nebo nástroj, který ještě nebyl vytvořen a správně vyzkoušen.

Sledování a pochopení fungování velkých programů vyžaduje velké úsilí a proces pochopení složitého programu trvá velice dlouho a dokáže být extrémně náročný. Cílem práce je tedy navrhnout a implementovat nástroj nástroj a pochopit principy, jež by ulehčily analýzu programů, které prostě a jednoduše dělají až moc věcí. Kvůli potencionální složitosti takového řešení se v této práci podíváme pouze na základní kameny takového nástroje, nicméně jsem otevřen tento nástroj do budoucna dále rozvíjet.

V úvodních kapitolách se podíváme na principy zejména z operačních systémů, od popisu systémových volání až po `ptrace`. Následně si ukážeme existující nástroje a jejich dobré a chybějící vlastnosti relevantní pro větší programy. Po těchto základních věcech se dostaneme konečně k samotné implementaci nástroje BouboTrace a její evaluaci a na závěr si všechno shrneme.

= Principy operačního systému Linux
Než se dostaneme k tomu, jak vlastně vůbec zjistit chování nějakého programu, musíme se nejdříve podívat na základy operačního systému Linux. Právě na něm jsem prováděl pak i veškerou další implementaci.

== Procesy
Každý spustitelný software, který je spuštěný v #abbr.a[OS] Linux, se navýzá proces. Procesy jsou uloženy ve stromu, každý proces má jednoho rodiče (kromě procesu `init`, který je kořenem) a může mít několik dětí. Každý proces je taky označený unikátním číslem, kterému se říká #abbr.a[PID].

Každý proces obsahuje jeho vlastní adresní prostor, jedná se o region v paměti, který obsahuje zpravidla data procesu, jeho zásobník a informace o posledních hodnotách v registrech. Za normálních okolností, kdy není použita forma komunikace mezi procesy, proces nevidí do adresního prostoru jiného procesu. @tanenbaum-operating[kap. 2.1] @core-dumped-process

Pro vytvoření nového procesu zavolá jiný, běžící proces, zpravidla systémové volání (díky kterému o něco požádá kernel, více v @syscalls[Kapitole]) `fork`. #footnote[Pro vytvoření procesů lze použít i jiné systémové volání, jako třeba `clone`, `vfork`, apod. nicméně všechny v základu fungují podobně, jako `fork`.] Kernel poté zkopíruje všechno o něm (adresní prostor, otevřené soubory, registry, atd.) a vytvoří nový proces, který je potomkem volajícího procesu. Rodiči vrátí #abbr.a[PID] potomka a potomkovi vrátí hodnotu $0$. Potomek vidí adresní prostor rodiče po jeho vytvoření, nicméně vzhledem k tomu, že jsou adresní prostory zkopírované, jakékoliv zápisy do paměti, které udělá rodič po vytvoření potomka potomek nevidí. @fork

Informace o procesech jsou dostupné ze speciálního souborového systému, `procfs`. Ten je zpravidla připojen na cestě `/proc` a obsahuje povětšinou read-only informace o procesech. Mezi tyto informace patří třeba parametry příkazové řádky, proměnné prostředí, symbolický odkaz na aktuálně spouštěný soubor a spuštěné vlákna procesu. Kernel taky odděluje procesy od vláken; každý proces může mít několik vláken kdy každé z nich obsahuje jiné data, než samotné procesy. @proc

=== Signály
Každý proces nebo vlákno může obdržet od kernelu nebo jiného procesu nějaký signál. Signály jsou způsoby, jak přerušit procesy a donutit je dělat něco jiného. @signal-overview ukazuje přehled některých signálů relevantních pro tuhle práci.

#figure(
  table(
    columns: (auto, auto),
    align: left,
    [*Signál*], [*Popis*],
    [`SIGSEGV`], [Proces provedl neplatný přístup do paměti],
    [`SIGKILL`], [Proces byl vynuceně ukončen],
    [`SIGSTOP`], [Proces byl zastaven],
    [`SIGTRAP`], [CPU vyvolalo během spouštění procesu breakpoint nebo debug trap],
    [`SIGILL`], [Proces se pokusil spustit neplatnou instrukci],
  ),
  caption: [Přehled některých signálů v Linuxu @signal]
) <signal-overview>

Každý signál má nějakou výchozí akci, kterou učiní. `SIGSEGV` terminuje proces a vytvoří core dump, `SIGTRAP` zastaví proces atd. Procesy mohou signály ignorovat, odložit a také spustit i speciální funkci, nazývanou jako signal handler (kdy proces odchytí daný signál). Jediné signály, které nejde ignorovat, odložit a odcyhtit jsou `SIGKILL`, kdy vždy dojde k ukončení procesu, a `SIGSTOP`, kdy vždy dojde k zastavení procesu. @signal


== Systémové volání <syscalls>
Moderní operační systémy izolují procesy v nich běžící od přímého přístupu k hardware. K tomu, aby proces mohl získat nějaká data z hardware, požádá o ně operační systém přes systémové volání. Způsob spouštění a předávání argumentů systémových volání se liší podle #abbr.a[OS] a podle architektury #abbr.a[CPU], #footnote[V případě x86-64 se k tomu dá použít instrukce `SYSCALL`. Parametry jsou předávány přes #abbr.a[CPU] registry. @intel-volume3[kap. 5.8.8] @syscall] nicméně ve valné většině případů existují knihovní procedury pro jazyk C (pro Linux se tato knihovna jmenuje `libc`) umožňující volat systémové volání. @tanenbaum-operating[kap. 1.6] Ve @write-example[Výpisu] lze vidět, jak můžeme využít jazyk C k použití systémového volání `write` k výpisu na standardní výstup.

#figure(
  raw(read("source_codes/write_example.c"), block: true, lang: "C"),
  caption: [Využití systémového volání `write` v C],
) <write-example>

Systémová volání zpravidla obsluhují vstup a výstup, třeba zápis na disk, komunikaci po síti nebo komunikaci přes #abbr.a[USB], nicméně může jít i o více komplikované věci, třeba uzamykání určitých oblastí paměti. #footnote[Viz manuálová stránka pro `mprotect`: https://man7.org/linux/man-pages/man2/mprotect.2.html.]

Pro účely této práce jsou taky skvělým způsobem, jak zjistit, co nějaký program dělá. Jedná se totiž o volání, které program musí *vždy* udělat, aby mohl provést některé akce, třeba zapsat na soubor nebo poslat nějaké data po síti. Program, který používá funkci `fread` ze standardní knihovny C vždy eventuálně volá `read` systémové volání, stejně jako program, který používá `read()` metodu na souboru v jazyce Python. Sledováním systémových volání tedy sledujeme veškerou interakci programu s _vnějším světem_.

Parametry knihovní procedury se ne vždy shodují s parametry systémového volání. V případě systémového volání `clone` jsou parametry mezi procedurou a reálným voláním jiné; liší se i mezi #abbr.a[CPU] architekturami. @clone Název procedury také nemusí odpovídat systémovému volání, který procedura volá. V příadě procedury `fork` se volá volání `clone`, i když `fork` má stejnojmenné systémové volání. @fork

==== Způsob spouštění systémových volání na x86-64
// TODO doplnit citaci na používanost
x86-64 je instrukční sada a architektura procesorů, vyvíjená primárně společnostmi Intel a AMD a využívaná na valné většině počítačů a notebooků. Je to taky ta, na které běží můj počítač a dále se v práci budu bavit pouze o ní, pokud nezmíním jinak.

Každý procesor obsahuje několik registrů, které sahají od #abbr.a[GP] registrů až po EFLAGS. S každým typem registrů se manipuluje jinak, #abbr.a[GP] registry jsou zapisovatelné přímo programem, segmentové registry může zapsat pouze kernel (v #abbr.a[CPL] 0). @intel-volume1[kap. 3.4] @intel-volume3[kap. 5.9] Jedním speciálním typem registru je registr RIP, který je známý také jako čítač instrukcí (anglicky program counter nebo instruction pointer), který obsahuje posun od počáteční adresy a po každé vykonané instrukci se přesouvá o délku této instrukce na začátek další instrukce. @intel-volume1[kap. 3.5.1]

Tyto procesory využívají konceptu #abbr.a[CPL] (známé taky jako protection rings), kdy pouze privilegované procesy (zde #abbr.a[OS]) mají přístup k privilegovaným instrukcím, které slouží zejména pro přímou manipulaci s hardware. Instrukce vykonané v #abbr.a[CPL] 0 vykonává pouze kernel, instrukce v #abbr.a[CPL] jsou vykonané všemi programy v userspace (mimo kernel). Aby proces zavolal systémové volání, využije k tomu instrukci `SYSCALL`. Ta přepne #abbr.a[CPL] do 0, načte RIP a #abbr.a[CS] registry z #abbr.a[MSR] a pokračuje dále kódem kernelu. Kernel pro návrat pak využije `SYSRET` instrukci, která dělá víceméně přesný opak toho, co dělá `SYSCALL`. @intel-volume3[kap. 5]

Pro předání typu systémového volání se používá #abbr.a[GP] registr RAX, pro parametry se pak používá registrů RDI, RSI, RDX, R10, R8 a R9. Pro návratové hodnoty se používá RAX a někdy i RDX registr. @syscall

=== Systémové volání `ptrace`
<ptrace-syscall>
Ačkoliv existuje velký počet způsobů, jak sledovat nějaký proces, v POSIX-ových operačních systémech musí všechny z nich eventuálně použít systémové volání `ptrace`.

#figure(
  ```c
  long ptrace(enum __ptrace_request op, pid_t pid, void *addr, void *data);
  ```,
  caption: [Parametry systémového volání `ptrace` @ptrace],
) <ptrace-params>

Definice knihovní procedury a systémového volání `ptrace` je ve @ptrace-params[Výpisu]. Její parametry jsou následující:
#argument_list(
  "op",
  [Definuje operaci pro `ptrace`. Přehled některých operací použitých v práci je v @ptrace-operations[Tabulce].],
  "pid",
  [#abbr.a[PID] procesu, na kterém chceme provést `op`.],
  "addr",
  [Použití tohoto parametru se liší dle `op`.],
  "data",
  [Použití tohoto parametru se liší dle `op`.],
)

Návratová hodnota záleží na `op`, některé operace vrací vyžádaná data a některé jenom hodnotu 0. Všechny nicméně vrací hodnotu -1, pokud dojde k chybě.

Proces, který používá `ptrace` na jiný proces (tzn. že zadává jeho #abbr.a[PID] do `pid` parametru) se nazývá "tracer" (sledovatel) a proces, který je sledován sledovatelem se nazývá "tracee" (sledovaný). Pojmy "sledovatel" a "sledovaný" budou nadále používány v práci. Ve většině konfiguracích, aby sledovatel mohl monitorovat sledovaný proces, musí sledovaný nejprve zavolat `ptrace(PTRACE_TRACEME)` a musí být potomkem sledovatele. #footnote[Podmínky pro sledování procesu se můžou měnit dle systému a konfigurace. Na některých systémech nelze `ptrace` použít vůbec, na jiných může jít sledovat průběh jakéhokoliv procesu, i pokud není potomkem. @ptrace]

Aby sledovatel mohl monitorovat sledovaný proces, musí sledovaný nejprve zavolat `ptrace(PTRACE_TRACEME)` a musí být potomkem sledovatele. #footnote[Tohle není nutně vždy pravda. `ptrace` má nastavitelné přístupové módy a můžou být jak více volné, tak i více limitující až kompletně zakázaný. @ptrace]

#figure(
  table(
    columns: (auto, auto),
    align: left,
    [*Operace*], [*Popis*],
    [`PTRACE_GETREGS`], [Uloží do ukazatele v parametru `data` hodnotu #abbr.a[CPU] registrů.],
    [`PTRACE_POKETEXT`], [Přečte jedno slovo z paměti sledovaného.],
    [`PTRACE_POKEUSER`], [Přečte slovo z USER regionu paměti sledovaného. Více v @breakpoint-creation[Kapitole].],
    [`PTRACE_TRACEME`], [Operace, kterou sledovaný umožňuje sledujícímu sledovat jeho proces.],
    [`PTRACE_SETOPTIONS`], [Umožňuje nastavit různé chování `ptrace`.],
  )
) <ptrace-operations>

==== Příklad inicializace `ptrace` <ptrace-example-chapter>
#figure(
  raw(read("source_codes/ptrace_example.c"), block: true, lang: "C"),
  caption: [Ukázka připojení k procesu přes `ptrace`],
) <ptrace-example>

Ve @ptrace-example[Výpisu] lze vidět základní nastavení používání `ptrace`. Nejprve je zavolána procedura `fork`, která zkopíruje vše o současném procesu do nového procesu, který je potomek současného procesu. Novému procesu (dítěti) dá návratovou hodnotu 0, rodiči vrátí #abbr.a[PID] dítěte. @fork Potomek potom zavolá `ptrace` s operací `PTRACE_TRACEME`, díky které dovolí rodiči dělat na daném procesu `ptrace` operace a zastaví sám sebe. Rodič tedy čeká (za pomocí systémového volání `waitpid`), než se dítě zastaví a jakmile je zastaveno, tak pokračuje #footnote[V korektní `ptrace` terminologii je sledovaný restartován.] s jeho spouštěním.


==== Práce se signály
Pokud sledovaný obdrží nějaký signál, tento signál mu nikdy není doručen. Místo toho je tento signál doručen přes systémové volání `waitpid` sledovateli. Je na sledovateli, jestli tento signál předá sledovanému (např. přes parametr `data` v operaci `PTRACE_CONT`) anebo zda ho nějak jinak zpracuje. Výjimku v tomto chování tvoří `SIGKILL`, který je sledovanému doručen přímo a sledovaný je díky tomu okamžitě ukončen. @ptrace @signal

==== Nastavení `ptrace`
`ptrace` umožňuje provést nějaké nastavení, kde ty podstatné možnosti pro tuhle práci jsou popsány v @ptrace-options-table[Tabulce].

#figure(
  table(
    columns: (auto, auto),
    align: left,
    [*Nastavení*], [*Popis*],
    [`PTRACE_O_TRACEEXEC`], [Informuje sledovatele o tom, že sledovaný zavolal `execve`],
    [`PTRACE_O_TRACEFORK`], [Informuje sledovatele o tom, že sledovaný zavolal `fork`],
    [`PTRACE_O_EXITKILL`], [Ukončí sledovaného, pokud sledovatel ukončí svůj běh]
  ),
  caption: [Popis možností v `ptrace`]
) <ptrace-options-table>

=== Systémové volání `process_vm_readv` a `process_vm_writev` <process-vm-chapter>
Abychom mohli přečíst argumenty, které byly předány do systémového volání a ukazují na nějaká data v paměti sledovaného, musíme zkopírovat paměť ze sledovaného do sledovatele. Je několik způsobů, jak tohoto dosáhnout, zde je výpis několika z nich: @trnka-thesis[kap. 4.2]

+ `ptrace(PTRACE_PEEKTEXT)` a `ptrace(PTRACE_PEEKUSER)` -- Výhodou těchto volání je, že jsou velice jednoduchá na použití. Stačí zadat adresu, ze které chceme číst a přečtená hodnota je vrácena jako návratová hodnota. Nevýhodou je, že lze číst pouze po jenom hardwarovém slově, tedy pro každé hardwarové slovo je potřeba udělat jedno volání. Ve výsledku je to poměrně efektivní řešení pro data o velikosti jednoho slova (např. registry), ale velice neefektivní pro větší data (např. řetězce).
+ Soubor `/proc/<pid>/mem` -- `<pid>` nahrazujeme za #abbr.a[PID] procesu; jedná se o speciální soubor, který umožňuje přes rozhraní souborového systému číst paměť procesu. Pokud tedy chceme z něj paměť přečíst, musíme ho nejdříve otevřít přes `open()` a poté přes `lseek()` #footnote[Systémové volání `open` a `lseek` lze nahradit za funkce ze standardní knihovny C (`fopen` a `fseek`).] se přesunout na adresu, kterou chceme číst. Nakonec použijeme systémové volání `read()` pro čtení adresy. @proc-pid-mem Jak si můžete všimnout, nevýhoda tohoto postupu je, že zahrnuje poměrně dost kroků a systémových volání pro čtení jedné adresy, nicméně oproti první metodě pro větší množství dat vyžaduje méně systémových volání.
+ `process_vm_readv`/`process_vm_writev` -- Systémové volání, které umožňují kopírovat přímo paměť mezi dvěma procesy. Výhodou je, že volání kopíruje data přímo mezi procesy, data jsou tedy kopírovány přímo z jednoho adresního prostoru do druhého a nedochází k předávání dat přes registry. Umožňují taky poměrně komplexní způsoby kopírování. @process_vm Nevýhodou je komplexnost použití, nicméně primárně díky rychlosti těchto systémových volání jsem je vybral jako způsob pro kopírování paměti ze sledovatele do sledovaného.

#figure(
  ```c
  ssize_t process_vm_readv(
      pid_t pid,
      const struct iovec *local_iov,
      unsigned long liovcnt,
      const struct iovec *remote_iov,
      unsigned long riovcnt,
      unsigned long flags
  );
  struct iovec {
      void   *iov_base;  /* Adresa, ze/do které chceme číst/zapisovat */
      size_t  iov_len;   /* Velikost paměti, do které ukazuje iov_base. */
  };
  ```,
  caption: [Parametry systémového volání `process_vm_readv` a `iovec` struktury @iovec @process_vm],
) <process-vm-readv>

Definice procedury `process_vm_readv` je popsána ve @process-vm-readv[Výpisu]. Popis jednotlivých parametrů je následující:
#argument_list(
  "pid",
  [#abbr.a[PID] procesu, ze kterého chceme číst.],
  "local_iov",
  [Pole struktur `iovec`, které ukazuje adresy a jejich délky, do kterých chceme načíst data z `remote_iov`.],
  "liovcnt",
  [Počet položek v `local_iov` poli.],
  "remote_iov",
  [Pole struktur `iovec`, které ukazuje na adresy a jejich délky, ze kterých chceme číst data do `local_iov`.],
  "riovcnt",
  [Počet položek v `remote_iov` poli.],
  "flags",
  [Nepoužitý argument, musí být nastaven na 0.],
)

Pokud se během kopírování naplní jedno `iov_base` pole v `local_iov`, přejde se na další v pořadí i pokud jsme pořád ve stejném poli v `remote_iov`. Jinými slovy, jedno pole v `remote_iov` může naplnit dvě pole v `local_iov` a opačně. V návratové hodnotě je celkový počet zkopírovaných bytů. Pokud `remote_iov` přesáhne do neplatné paměti, celé kopírování okamžitě skončí a systémové volání vrátí počet zkopírovaných bytů do té doby. Tohle použití je velice relevantní pro implementaci v této práci a je více rozebráno v @syscall-loading[Kapitole].

= Programovací jazyk Rust
Pro implementaci programu v práci jsem se rozhodl pro jazyk Rust. Jedná se o paměťově bezpečný nízkoúrovňový systémový jazyk, který klade důraz na výkon, paralelní zpracování a typovou bezpečnost. Nepoužívá žádnou formu automatické správy paměti; místo toho používá "borrow checker," který kontroluje platnost referencí a dobu jejich života během překladu. Všechny proměnné jsou také ve výchozím stavu "non-mutable" tzn. že nelze přepsat jejich obsah. Půjčuje si hodně vzorů z funkcionálních jazyků, nicméně objevuje se v něm i pár konceptů z OOP. Jazyk je paměťově bezpečný, je tudíž garantováno, že nedojde během běhu programu k #abbr.a[UB] (zápis mimo platnou paměť, čtení z nulového ukazatele apod.). Výjimku v tomto tvoří `unsafe` bloky, které v jazyce existují, protože ne všechno v nízkoúrovňovém programování může být paměťově bezpečné. @rust-book

Jazyk Rust používá systém Cargo pro správu závislostí, testů, parametrů překladu, verze programu a mnoho dalšího. Jedním z konceptů v Cargo je "crate" (dále balíček) jedná se o nějaký modul, který je dostupný lokálně nebo z internetu a jakmile je přidaný do současného projektu, je možné importovat jeho veřejné členy v současném projektu. Tyto balíčky pak lze sdílet na #link("https://crates.io/")[`crates.io`] a díky tomu jednoduše používat v jiných projektech jako závislosti. @rust-book[kap. 7] 

Rust rovněž umožňuje propojení s jinými nízkoúrovňovými programovacími jazyky za pomocí #abbr.a[FFI]. Je tedy možné poměrně jednoduše volat funkce z jazyků C nebo C++. Všechny funkce definované přes #abbr.a[FFI] jsou ve výchozím stavu unsafe, nicméně lze kolem nich udělat bezpečné rozhraní, jak je tomu ve @ffi-example[Výpisu]. @rustonomicon[kap. 11]

#figure(
  raw(read("source_codes/ffi/src/lib.rs"), block: true, lang: "rust"),
  caption: [Ukázka použití knihovny `snappy` přes #abbr.a[FFI] v jazyce Rust. @rustonomicon[kap. 11]],
) <ffi-example>

Jazyk Rust jsem zvolil, protože jsem vyžadoval jazyk, který dokáže pracovat přímo s pamětí procesu pro manipulaci a čtení během sledování systémových volání, nechtěl řešit v mém programu nějaké #abbr.a[UB] a potřeboval jsem vysoký výkon, aby sledující byl zastavený pouze po co nejkratší nutnou dobu a nebyl tak silně bržděn.

== Balíček `nix`
Balíček `libc` obsahuje všechny #abbr.a[FFI] definice pro systémová volání v Linuxu. Balíček `nix` kolem nich vytváří bezpečná rozhraní. Rozdíl definice systémového volání `write()` mezi `libc` a `nix` balíčky je zobrazený ve @write-difference[Výpisu]. Zatímco `libc` implementace mapuje `write()` přímo, `nix` obal se ptá na typ z Rustu a vrací typ `Result`, který vynucuje ošetřit vrácené chyby. To je hlavní a primární rozdíl mezi jak `libc` definicí, tak přímého volání z C.

#figure(
  ```rust
  // libc
  pub unsafe extern "C" fn write(fd: c_int, buf: *const c_void, count: size_t) -> ssize_t
  // nix
  pub fn write<Fd: AsFd>(fd: Fd, buf: &[u8]) -> Result<usize>
  ```,
  caption: [Porovnání systémového volání `write` mezi `nix` a `libc`. @libc-rust @nix-rust],
) <write-difference>

Pro všechny přímé systémové volání jsem v práci byl využil balíček `nix`. Některé potencionálně užitečné definice struktur a systémových volání v něm někdy nejsou nadefinované, #footnote[Příkladem zde je operace `PTRACE_GET_SYSCALL_INFO`. Je dostupná v `libc`, ale v `nix` zatím nebyla implementována. Je o tom již dlouhodobě aktivní PR: https://github.com/nix-rust/nix/pull/2006.] nicméně dá se bez nich většinou obejít a případně je zavolat nebo importovat z `libc`.


= Existující alternativy <existing-solutions>
V této kapitole se podíváme na existující nástroje, které umožňují sledovat chování procesů v Linuxu. U každé z nich je uveden krátký popis včetně toho, proč je její použití vhodné či nevhodné.

== strace <strace-solution>
`strace` je velice populární nástroj na analýzu systémových volání procesu. Umí spustit nějaký proces a vypsat všechna systémové volání, které provedl, a to včetně návratových hodnot. @strace Nevýhodou je komplexnost výstupu. I v případě jednoduchých programů, jako lze vidět ve @open-example[Výpisu], který používá celkem tři systémové volání, vrátí `strace` několik jiných systémových volání, které nejsou součástí reálného programu. Výstup `strace`, ze kterého jsem vynechal tyto zbytečné systémové volání, lze vidět ve @strace-output[Výpisu]. Je to z toho důvodu, že ELF formát obsahuje několik systémových volání, které se spustí před vstupem do samotného programu. Více je tohle rozebrané v @skip-to-main[Kapitole]. Výstup z `strace` navíc není dobře strojově zpracovatelný a nedá se použít jako knihovna.

#figure(
  raw(read("source_codes/open.c"), block: true, lang: "c"),
  caption: [Jednoduchý program používající `open` systémové volání],
) <open-example>

#figure(
  raw(read("sources/strace_open.txt"), block: true),
  caption: [Výstup `strace` pro @open-example],
) <strace-output>

Další nevýhodou `strace` je čistá komplexnost výstupu u velkých programů. Zejména jakmile program začne pracovat s vlákny, může být analýza výsledného výstupu velice matoucí a může být obtížné v ní něco najít. `strace` je skvělý nástroj na rychlou opravu chyby (třeba když systémové volání vrátí chybu, kterou daný program neodchytil), ale rozhodně ne na rozsáhlou analýzu a pochopení programu.

== intentrace
intentrace #footnote[https://github.com/sectordistrict/intentrace] je nástroj v beta verzi, který má za úkol zjednodušit čtení `strace`. Ačkoliv tohle nástroj dělá výborně, přichází na stejné problémy, jako `strace` -- výstup obsahuje až moc informací. Výstup `intentrace` pro program ve @open-example[Výpisu] se nachází ve @intentrace-output[Výpisu]. Tento výstup je mnohem lépe lidsky čitelný, ale pořád není to, co bych potřeboval.

#figure(
  raw(read("sources/intentrace_output.txt"), block: true),
  caption: [Výpis programu ve @open-example[Výpisu] v nástroji `intentrace`, s odstraněnými ANSI kódy]
) <intentrace-output>


== Krokování pomocí ladícího nástroje
Krokování je běžným způsobem diagnostiky chyb chování programu. Umožňuje nám postupně procházet určitě části programu a dívat se, co je s nimi špatně nebo dobře. Problém krokování je, že umí nakreslit pouze části do puzzle chování programu, nikoliv celé puzzle. Skládání puzzle je už na programátorovi. Tento postup funguje, když má puzzle 100 dílků; když jich má 50~000, nefunguje už tak moc dobře.

// TODO dopsat
= Návrh

= Implementace nástroje BouboTrace <implementation>
V této kapitole se nejprve podíváme na strukturu kódu v BouboTrace a poté si něco řekneme o věcech, které byly dokončeny a jaké problémy to obnášelo. V celé kapitole se probírá pouze x86-64 instrukční sada a architektura, pokud není zmíněno jinak.

== Struktura BouboTrace
BouboTrace obsahuje několik komponent, které dohromady tvoří celý nástroj. Program je rozdělený na knihovní a aplikační kód, kdy knihovní kód se stará o čtení systémových volání a aplikační kód o spuštění sledovaného programu a #abbr.a[CLI].

=== Rozhraní pro práci s knihovním kódem
První jsem se musel rozmyslet nad smysluplným rozhraním, které by dokázalo vhodně reprezentovat jedno systémové volání. V jazyce Rust jsou velice oblíbené iterátory, které velice vhodně reprezentují nějakou sekvenci dat. Původní navrhované rozhraní pro program lze vidět ve @first-interface[Výpisu].

#figure(
  ```rust
  for syscall: Syscall in tracee.run() {
      if let Syscall:Write(_, _, bytes) = syscall {
          println!("called write with {bytes:?}");
      }
  }
  ```,
  caption: [Představované původní rozhraní pro (uživatelský) kód spustitelného souboru.],
) <first-interface>

Ze začátku tento postup fungoval skvěle, nicméně eventuálně jsem narazil na problém chyb; uživatel by měl být informován o chybách, knihovní kód by si je neměl nechávat pro sebe. Mezi možné chyby patří nějaká chyba z `ptrace` (např. když je daný region paměti uzamknut, proces s daným #abbr.a[PID] neexistuje atd.), ale i chyba ze systémového volání (více popsáno v @syscall-errors[Kapitole]). Jako chyby jsou předávány i různé události (třeba ukončení procesu). Finální typ iterátoru je tedy `Result<Syscall, SyscallParseError>`, uživatel je tak informován o všech chybách a událostech. Příklad finálního čtení iterátoru je ukázán ve @final-interface[Výpisu].
#figure(
  ```rust
  for syscall in tracee.run() {
      match syscall {
          Ok(syscall) => println!("received syscall: {syscall:?}"),
          Err(syscall_error) => println!("an error occurred: {syscall_error}"),
      }
  }
  ```,
  caption: [Finální rozhraní uživatelského kódu],
) <final-interface>

// FIXME přesunout nejspíš trochu níž
=== Struktura `Tracee` <tracee-struct>
Struktura `Tracee` představuje obal nad `ptrace` rozhraním z balíčku `nix`. Je to z toho důvodu, že některé složitější operace v `ptrace` jsou poměrně časté, chtěl jsem nad nimi tedy nějaký obal, abych pro jejich úpravu nemusel měnit kód na několika místech. `Tracee` rovněž enkapsuluje #abbr.a[PID] sledovaného, nelze tedy přečíst ze zbytku knihovního kódu a všechny `ptrace` operace musí proběhnout přes metody `Tracee`.

`Tracee` obsahuje jak jednoduché metody (např. `read`, `write`, `read_rax` atd.), tak i složitější metody s náročnější logikou. Jednou z nich je třeba `memcpy_until`, která za pomocí `process_vm_readv` systémového volání kopíruje paměť ze sledovaného do sledovatele a každém bytu této kopírované paměti spouští předanou anonymní funkci. Pokud ta vrátí hodnotu `true`, tak je kopírování ukončeno. Mezi další metody patří třeba `strcpy`, která obaluje `memcpy_until`, dokud není načtený celý C řetězec. Podrobnější popis fungování těchto metod je poskytnut v @syscall-loading[Kapitole].

Nakonec jsou zde i metody na `wait_for_stop`, `cont` a `syscall`. V @ptrace-syscall[Kapitole] bylo popsáno, že signály jsou vždy doručené sledovateli a nikoliv sledovanému. Je čistě na sledovateli (tedy nás), co s daným signálem dělat. Všechny doručené signály jsou doručené v `waitpid` systémovém volání, které je volané ve `wait_for_stop` metodě. Pokud je tedy sledovaný zastaven na nějakém signálu, je tento signál uložen ve struktuře a poté předán sledovanému při volání `cont` nebo `syscall` metody. Výjimku tvoří SIGKILL, jelikož ten kernel doručuje přímo sledovanému @ptrace a SIGTRAP, který signalizuje trap signál z #abbr.a[CPU] a je používaný pro nastavení breakpointu. Více je tohle rozebrané v @breakpoint-creation[Kapitole].

=== Enum `Syscall`
Enum `Syscall`  obstarává načítání všech implementovaných systémových volání. Obsahuje metodu `parse`, která vezme referenci na strukturu `Tracee`, na které byla zavolána metoda `syscall` a čeká, až se zastaví na vstupu do systémového volání. Poté načte všechny parametry systémové volání (čísla, řetězce, příznaky, pole, apod.), zavolá `syscall` metodu a poté přečte návratovou hodnotu.

Pokud během čtení dojde k nějaké chybě, ať už z `ptrace` nebo z návratové hodnoty systémového volání, vrátí metoda `parse` chybu ve formě typu `SyscallParseError`. Tento typ umožňuje zahrnout hromadu chyb a stavů, od chyby `ptrace` přes ukončení sledovaného až po chybu systémového volání. Je to taky typ, který je vrácen v iterátoru. Pokud čtení proběhne úspěšně, vrátí metoda instanci enumu `Syscall`, který obsahuje přečtené systémové volání.

=== Aplikační kód
Aplikační kód BouboTrace zahrnuje způsob, jak spustit sledovaného a taky #abbr.a[CLI]. Pro čtení parametrů z příkazové řádky jsem použil balíček `clap`, který umožňuje velice jednoduše číst argumenty v příkazovém řádku do struktur. Po přečtení parametrů, které zahrnují například úroveň logování, název spouštěného programu, jeho pracující složku a různé další věci, dojde ke spuštění sledovaného. Jak bylo zmíněno v @ptrace-example-chapter[Kapitole], pro inicializaci `ptrace` je potřeba, aby dítě zavolalo `PTRACE_TRACEME` operaci. Sledující musí tedy provést následující kroky:

+ Zavolat `fork` (nebo `clone`) a tím vytvořit kopii sama sebe.
+ V rodiči počkat na zastavení dítěte.
+ V dítěti zavolat `PTRACE_TRACEME` operaci.
+ V dítěti zavolat `execve` systémové volání, které nahradí daný program s programem zadaném v argumentu volání. Ve zkratce _nahradí_ současný program za jiný.

Jazyk Rust obsahuje ve standardní knihovně strukturu `Command`, která umožňuje spustit program jako dítě současného programu. Disponuje i unsafe metodou `pre_exec`, která obsahuje anonymní funkci, která se spustí v dítěti před samotným programem. Povedlo se mi nicméně najít balíček `spawn_ptrace`, #footnote[https://docs.rs/spawn-ptrace/latest/spawn_ptrace/] který celý tento proces dokáže automatizovat a chybově ošetřit.

== Čtení systémových volání
`ptrace` systémové volání, diskutované v @ptrace-syscall[Kapitole], obsahuje operaci `PTRACE_SYSCALL`. Tato operace zastaví sledovaného vždy při vstupu a výstupu ze systémového volání. Vzhledem k tomu, že nás primárně zajímají jenom systémová volání, je tato operace ideální, jelikož nabízí nejmenší komplexitu.

Sledovaný je zastaven vždy po volání systémového volání a pokud je poté restartován opět s `PTRACE_SYSCALL` operací, tak je opět zastaven těsně před východem ze volání. V prvním případě můžeme přečíst argumenty předané do systémového volání a jaké systémové volání proběhlo, #footnote[RAX obsahuje číslo systémového volání, když sledovaný volá `SYSCALL`; neobsahuje ho během systémového volání. Kernel nicméně ukládá původní hodnotu v `orig_rax` hodnotě v USER části paměti. Více o USER části v @breakpoint-creation[Kapitole].] v druhém případě návratovou hodnotu volání.

V x86-64 architektuře jsou parametry systémového volání předávané přes registry. @syscall Koncept kódu pro čtení parametrů a návratových hodnot všech systémových volání se nachází ve @ptrace-concept[Výpisu]. Proces operací je následující:

+ Zavoláme `PTRACE_SYSCALL` operaci na #abbr.a[PID] sledovaného
+ Počkáme, než se sledovaný dostane do zastaveného stavu
+ Přečteme parametry systémového volání z uživatelského regionu paměti sledovaného #footnote[`ptrace` k tomuhle nabízí `PTRACE_GETREGS` operaci, nicméně lze i číst z USER regionu paměti, jelikož tam jsou registry uloženy vždy při výměně procesu na #abbr.a[CPU].]
+ Opět zavoláme `PTRACE_SYSCALL`
+ Počkáme, než se sledovaný opět zastaví
+ Přečteme z uživatelského regionu (více rozebrané v @breakpoint-creation) paměti hodnotu registru RAX
+ Pokračujeme se spouštěním sledovaného

#figure(
  ```rust
  ptrace::syscall(pid)?;
  wait_until_stop(pid)?;
  let regs = ptrace::getregs()?;
  let args = (regs.rdi, regs.rsi, regs.rdx, ... )?  // všechny x86-64 argumenty
  ptrace::syscall(pid)?;
  wait_until_stop(pid)?;
  let return_value = ptrace::read_user(pid, (RAX * 8))?;  // přečte jenom RAX registr
  ptrace::cont(pid)?;
  ```,
  caption: [Koncept čtení parametrů a návratové hodnoty systémového volání],
) <ptrace-concept>

V úplně stejném principu je sledování systémových volání implementované v práci, v souboru `syscall.rs`. Čtení parametrů systémových volání nicméně není vždy tak jednoduché a vyžaduje trochu zpracování navíc.


=== Chyby v systémových volání <syscall-errors>
Hlavní registry x86-64 jsou 64bitové a v Linuxu jsou používané jako `i64` (v jazyce C `long`) datový typ. Jedná se tedy o 64bitové číslo s dvojkovým doplňkem. Pokud systémové volání chce vrátit nějakou chybu (např. `openat` byl požádán o vytvoření souboru ve složce, ve které nemá práva), vrátí v RAX registru číslo chyby jako záporné číslo. V tomhle případě `openat` chce vrátit `EACCES`. Číslo #footnote[Pro zjištění čísla chyb je skvělý program `errno`, součástí moreutils.] `EACCES` chyby je $13$, tedy `openat` do RAX registru zapíše číslo $-13$.

Je dobré zmínit, že knihovní procedury v C místo vrácení záporného čísla chyby vrátí vždy $-1$ a hodnotu chyby nastaví do statické proměnné `errno`. @errno Jak už ve zmíněném `fork` a `clone` případu, jedná se o další rozchod mezi procedurami v C a reálnými systémovými voláními, nicméně tento postup zajišťuje větší přenosnost mezi architekturami.


=== Načítání dat v parametrech systémových volání <syscall-loading>
Systémové volání obsahují rozdílné parametry, které říkají rozdílné věci. Z @write-example[Výpisu] můžou být už zjevné parametry `write`, nicméně pro připomenutí, ve @write-open-definitions[Výpisu] se nachází parametry pro `write` a `openat` systémové volání.

#figure(
  ```c
  int openat(int dirfd, const char *pathname, int flags, ... /* mode_t mode */);
  ssize_t write(int fd, const void buf[.count], size_t count);
  ```,
  caption: [Parametry pro `write` a `openat` systémové volání @open @write],
) <write-open-definitions>

Přečíst všechny číselné datové typy (`int`, `long`, atd.) je velice jednoduché, stačí pouze načíst hodnotu z daného registru a poté správně přetypovat. Problém nastává u ukazatelů, kdy musíme načíst adresu (a vědět, kolik bytů z ní načíst) a u příznaků.

==== Čtení dat fixní délky
Pro načtení pole z paměti sledovaného v práci využívám systémové volání `process_vm_readv`, popsané v @process-vm-chapter[Kapitole]. Naštěstí u systémových volání s fixní délkou dat je délka dat předána v jiném parametru (v případě `write` jde o poslední). Pokud potřebujeme načíst strukturu, zjistíme si přes `std::mem::size_of::<T>()` funkci její velikost v bajtech a tu pak načteme.

==== Čtení dat variabilní délky
Nejčastějším příkladem čtení dat variabilní délky je C řetězec. C řetězec je sekvence bytů, která je ukončena bytem `0x00`. V kernelovém prostoru má C řetězec poměrně častý výskyt, dále se tedy budu bavit pouze o ní. Celý proces jsem graficky znázornil v @chart-variable-loading[Obrázku].

Při načítání řetězce je třeba myslet na následující otázky:
- #underline[Kde je konec načítaných dat?]

  V případě C řetězce je tato odpověď poměrně jednoduchá, jedná se o byte `0x00`, nicméně problém nastává v tom, že nemůžeme jednoduše číst paměť sledovaného (možnosti čtení jsem rozebral v @process-vm-chapter[Kapitole]) a provádět na ni hledání. Jedním z nápadů je si paměť sledovaného zkopírovat do sledovatele, jenže abychom tohle mohli provést, musíme znát délku dat. Řešením je tedy načítat data po částech do bufferu a v každé načtené části vyhledat ukončovací znak; jakmile je nalezen, data v té části uřízneme a považujeme za načtené.

- #underline[Může načtených dat být _až moc_?]

  C řetězec nemá jasnou délku. Může obsahovat jak 10 bajtů, tak i 2 GiB. Kopírovat takový počet dat by bylo velice neefektivní. Řešením zde je nastavit tvrdou hranici kopírování, kdy počet zkopírovaných dat je _až moc_ velký. Pro tuhle práci jsem zvolil limit 2 MiB, dle mé znalosti ho ani jeden ze všech testovaných programů v @correctness[Kapitole] nepřekročil.

- #underline[Můžeme během čtení narazit na neinicializovanou paměť?]

  Ano, můžeme. Nicméně volání `process_vm_readv` v tom případě nevrací chybu, ale pouze načte méně dat. Že se tomu tak stalo je zjevné z návratové hodnoty, čili lze lehce detekovat, že byl proveden pokus o přečtení neplatné paměti. V tom případě ukončíme čtení.

- #underline[Obsahují načtená data reálně znaky řetězce?]

  V případě řetězců C cokoliv předpokládat je obrovská chyba. Jedná se o `char*`, kde `char` je jakékoliv 8bitové číslo. Systémová volání používají plně UTF-8, @linux-unicode a u typu `char*` není spoleh, zda jsou znaky v řetězci validní. `String` a `str` struktury a typy v jazyce Rust nicméně vyžadují validní UTF-8, čili možné způsoby, jak uložit C řetězec v jazyce Rust jsou:
  + Pokusit se o kontrolu validity UTF-8 a uložit jako `String`

    Tato metoda dává na povrchu největší smysl, řetězec by měl být uložen v řetězci, nicméně jak jsem psal, `String` typ vyžaduje platnou UTF-8 sekvenci, která nemusí být předána ve volání. Daný řetězec by potom nemohl být reprezentovaný jako instance typu `String`.
  + Využít strukturu `CString`, jedná se o strukturu ve standardní knihovně jazyku Rust, která slouží k napodobení chování `char*`.
  + Pracovat s C řetězci jako s vektorem bytů, `Vec<u8>`

Převody mezi těmito strukturami jsou jednoduché, akorát převody do `String` mohou vrátit chybu, pokud řetězec obsahuje neplatné UTF-8 sekvence. V práci jsem se rozhodl pro možnost s `Vec<u8>`, ale i použití `CString` by bylo plně možné.

#figure(
  image("sources/variable_reading.svg"),
  caption: [Diagram načítání dat variabilní délky],
) <chart-variable-loading>

==== Načítání příznaků
Binární příznaky (bitwise flags) jsou čísla, kde hodnota jednoho bitu značí nějaký přepínač. Ve @openat-flags[Výpisu] lze vidět použití těchto příznaků u systémového volání `openat`. V @openat-flags-desc[Tabulce] lze vidět popis použitých příznaků. Všimněte si, že binární hodnota příznaku obsahuje jiné bity pro jednotlivé příznaky. Přes logický OR tedy můžeme zkombinovat více příznaků do jednoho čísla, které pak můžeme předat jako číslo v parametru systémového volání. @flags-beauty

#figure(
  ```c
  int fd = openat("file.txt", O_CREAT | O_TRUNC | O_WRONLY, S_IRWXU);
  ```,
  caption: [Využití binárních příznaků u systémového volání `openat`],
) <openat-flags>

#figure(
  table(
    columns: (auto, auto, auto),
    align: left + horizon,
    table.header(
      [*Název příznaku*],
      [*Dvojková hodnota příznaku* #footnote[Jedná se o hodnotu příznaku na mém systému; může se lišit podle architektur]],
      [*Popis příznaku*],
    ),

    [`O_CREAT`], [`0001000000`], [Vytvoří soubor, pokud neexistuje],
    [`O_TRUNC`], [`1000000000`], [Pokud soubor existuje, vymaže při otevření veškerý jeho obsah],
    [`O_WRONLY`], [`0000000001`], [Otevře soubor pouze pro zápis],
  ),
  caption: [Popis příznaků použitých ve @openat-flags[Výpisu] @open],
) <openat-flags-desc>

Problém načítání příznaků je, že se jedná _pouze o číslo_. Pokud tedy chceme zjistit hodnotu příznaku, musíme z číselné hodnoty přečíst nastavené bity a pak zjistit, jaké nastavení každý bit reprezentuje. V C by tohle bylo poněkud obtížné, protože všechny možnosti jsou nadefinované jako makra a nelze je tudíž jednoduše převést během běhu programu do textové podoby. @flags-beauty V jazyce Rust záleží, z jakého balíčku příznaky bereme. Všechny makra převzaté z C jsou nadefinované v balíčku `libc` jako konstantní čísla, ve své podstatě se tedy chovají stejně, jako příznaky z C a jejich převod do textové podoby by vyžadoval napsání sady podmínek, ruční pojmenování každého bitu a poté převod do řetězce. Nejedná se o složitý postup, nicméně je poměrně pracný.

Balíček `nix` používá vlastní implementaci balíčku `bitflags`. #footnote[https://docs.rs/bitflags/latest/bitflags/] Tento balíček umožňuje pracovat s příznaky pomocí ergonomického rozhraní. Umožňuje jednoduše příznaky nastavit, ale hlavně vypsat a získat z čísla. Jak tohle vypadá v praxi ukazuje @oflag-flags[Výpis], kde je ukázka načítání příznaků (v praxi by se hodnota načítala z registru místo proměnné).

#figure(
  ```rust
  let flags = libc::O_CREAT | libc::O_TRUNC;
  let flags = fcntl::OFlag::from_bits(flags).unwrap();
  println!("{flags:?}");  // OFlag(O_CREAT | O_TRUNC)
  ```,
  caption: [Příklad inicializace `nix::fcntl::OFlag` příznakové hodnoty],
) <oflag-flags>

#show link: it => {
  if type(it.dest) != str { it } else { emph(it) }
}

== Spuštění ve vstupním bodu <skip-to-main>
Při psaní v nízkoúrovňových jazycích používáme zpravidla funkci `main` jako první věc, která se v programu spustí. Při překladu a linkování programu dochází k vytvoření souboru ve formátu ELF, který obsahuje jak přeložený kód, tak i nějaké informace k němu.

Pro spuštění programu se v Linuxu používá systémové volání `execve`. Jako první parametr přijímá cestu k souboru (zpravidla v ELF formátu #footnote[`execve` umožňuje volat přímo interpretry pro jazyky, které to vyžadují. Pokud třeba soubor, který začíná s `#!/usr/bin/bash` je předán do `execve`, je místo souboru přímo spuštěn `/usr/bin/bash` s cestou k souboru jako první argument.]). Pokud tento soubor vyžaduje dynamické linkování, je zavolaný interpreter pro načtení sdílených objektů (zpravidla `ld-linux.so`). @execve A tím je konečně vysvětlený můj problém s nástrojem `strace`, vysvětlený dávno v @strace-solution[Kapitole]. Jako první systémové volání ihned po `PTRACE_TRACEME` operaci bývá `execve` samotného programu a poté, pokud ELF závisí na dynamických knihovnách, dochází k dynamickému linkování, během kterého dojde k několika systémovým voláním. Až po tomhle všem dorazí sledovaný do funkce `main`.

Formát ELF obsahuje několik sekcí, @elf-diagram kdy každá z nich obsahuje nějaké informace o programu. Pro nás největší význam tvoří položka `e_entry` (dále jako vstupní adresa), která se nachází v hlavičce ELF souboru. Tato položka značí adresu ve virtuální paměti,
#footnote[V tomto kontextu je virtuální paměť paměť relativní k danému ELF souboru, s tím, že adresa `0x0` odkazuje na start ELF souboru. @elf V praxi přístup k této adrese je složitější, více o tom v @memory-maps[Kapitole].]
která značí počátek instrukcí (kódu) v ELF souboru. @elf Pokud tedy program spustíme, necháme běžet, zastavíme ve vstupní adrese a až poté budeme sledovat systémové volání, přeskočíme tím všechny volání způsobené dynamickým linkováním.

Pro načtení vstupní adresy v jazyce Rust jsem použil balíček `elf`. #footnote[https://docs.rs/elf/latest/elf/] Do něj stačí předat ELF soubor, který můžeme najít přes `procfs` v souboru `exe` a provést minimální čtení ELF souboru. @proc-pid-exe Minimální čtení umožňuje přečíst obsah hlavičky, ve které se vstupní adresa nachází.

=== Vytvoření breakpointu <breakpoint-creation>
Většina programátorů zná breakpoint jako řádek v kódu, kde se jejich program zastaví a oni mohou přečíst hodnoty proměnných za běhu. Pro účely jejich vytvoření musíme použít nicméně více konkrétní definici; breakpoint je v paměti sledovaného adresa, kam když dojde čítač instrukcí, tak sledovaný obdrží (zpravidla) SIGTRAP signál a je zastaven. Jak bylo zmíněno v @ptrace-syscall[Kapitole], sledovaný nedostává žádné signály přímo, ale sledovatel je informován, že sledovaný nějaký signál obdržel.

První možnost, jak dosáhnout breakpointu, je použít `ptrace` operaci `PTRACE_SINGLESTEP`. Ta program posouvá vždy o jednu instrukci. Pokud bychom tedy opakovaně volali tuhle operaci a při každém volání se podívali na adresu v čítači instrukcí a porovnali ji se vstupní adresou ELFu, budeme informování přesně o bodu před začátkem našeho kódu. Tento postup nicméně obsahuje dva problémy. Zaprvé, RIP registr (čítač instrukcí) nelze číst.
#footnote[
  Registr RIP nelze číst..._přímo_. Pro nepřímé čtení lze použít nějakou instrukci, která skáče mezi adresami v paměti (např. `CALL`). Tyto instrukce vždy nahrají současnou hodnotu RIP do zásobníku a nahrají do něj jinou, nadefinovanou adresu. Instrukce `RET` pak ze zásobníku přečte první položku a nahraje ji do RIP registru. @intel-volume1[kap. 3.5] @intel-volume2
]
Zadruhé, volat `ptrace` pro krokování každé instrukce je velice neefektivní. Z obou těchto důvodu tohle řešení nepřipadá absolutně v úvahu, proto mnohem lepším řešením je vyvolat SIGTRAP ve správný čas a hlavně na správném místě.

Jak tedy vyvolat SIGTRAP na místě, kde ho potřebujeme? SIGTRAP signál je doručen, pokud na #abbr.a[CPU] dojde k breakpoint exception (\#BP). @signal Dle Intel 64 manuálu pro x86-64 #abbr.a[CPU], je několik způsobů, jak \#BP vyvolat a pro nás jsou relevantní dva z nich.

==== Instrukce INT3
Instrukce INT3 (opcode `0xCC`) vyvolává \#BP. Má velikost přesně jednoho bytu, aby mohla nahradit celou nebo část jakékoliv instrukce. @intel-volume2[kap. 3.3] V praxi tedy byte na adrese, kde chceme udělat breakpoint, uložíme v paměti sledovatele, nahradíme ho za `0xCC` a jakmile zjistíme, že sledovaný obdržel SIGTRAP, nahradíme změněný byte za původní a pokračujeme ve spouštění sledovaného. INT3 generuje na #abbr.a[CPU] chybu kategorie trap, která posune RIP za adresu této instrukce. @intel-volume3[kap. 6.5] Registr RIP nicméně není přímo zapisovatelný.

`ptrace` umožňuje číst ze dvou regionů paměti: USER region a data programu. USER region obsahuje primárně registry, ale je v něm i pár věcí navíc. Abychom načetli něco z USER regionu, můžeme použít `PTRACE_PEEKUSER` operaci. Soubor `<asm/ptrace-abi.h>` obsahuje všechny posuny pro všechny #abbr.a[GP] registry. Pokud tedy chceme přečíst čistě RAX registr, stačí využít těchto posunů a prakticky to lze vidět ve @ptrace-concept[Výpisu] a ve @breakpoint-creation-example[Výpisu]. Kernel zapisuje do USER regionu při vyhození procesu z #abbr.a[CPU] a načítá z něj, když dává proces zpátky na #abbr.a[CPU].

Musíme tedy uložit původní slovo, nahradit ho za `0xCC` byte, počkat než program vyhodí SIGTRAP, vrátit zpátky původní slovo a dekrementovat RIP. V literatuře a na internetu se tomuhle postupu říká softwarový breakpoint. @breakpoints @breakpoint-creation-example ukazuje tvorbu tohoto breakpointu v jazyce Rust.

#figure(
  ```rust
  // uložení původního slova
  let original_word = tracee.read(breakpoint_address)?;
  tracee.write(breakpoint_address, 0xCC)?;
  tracee.cont()?;

  // čekání, než program dorazí k 0xCC instrukci
  match tracee.wait_for_stop() {
      Ok(WaitEvents::Stopped(Signal::SIGTRAP)) => {
        // dekrementování RIP registru
        let rip = tracee.read_user((RIP * 8) as usize)? as usize;
        tracee.write_user((RIP * 8) as usize, (rip - 1) as i64)?;
        // nahrazení původního slova
        tracee.write(main_address, original_word)?;
      }
      _ => panic!(),
  }
  ```,
  caption: [Ukázka vytvoření softwarového breakpointu]
) <breakpoint-creation-example>

Tento postup jsem zvolil i v práci, primárně díky jeho jednoduchosti, ale taky, protože jsem úplně nevěděl o druhém způsobu.

==== Ladící registry
x86-64 nabízí několik ladících registrů, označené DR0 až DR7. Je možné do nich zapisovat pouze z #abbr.a[CPL] 0.

Struktura celého USER regionu, zmíněného v předchozí kapitole, se nachází ve struktuře `user`, definované v `<sys/user.h>`. #footnote[Doporučuji se do tohoto souboru podívat jenom kvůli jeho úvodnímu blokovému komentáři o #abbr.a[GDB].] Úplně poslední částí této struktury je pole o velikosti 8 64bitových čísel pojmenované `u_debugreg` a právě tohle obsahuje debug registry, od DR0 po DR7. Pokud je tedy proces zastaven, můžeme nastavit zde jakoukoliv vyžadovanou hodnotu a kernel ji poté načte do #abbr.a[CPU] když #abbr.a[CPL] je 0.

Teď když víme, jak načíst hodnotu do ladící registru, jaké hodnoty tam vlastně chceme načíst? Pokud se vrátíme ke svaté bibli x86-64 (odkaz na kapitolu v citaci), zjistíme, že registry DR0 až DR3 drží nějakou adresu v paměti, DR6 obsahuje informace o poslední vygenerované \#BP a DR7 obsahuje nastavení ladění. Zbytek je registrů rezervovaný (nejspíše už navždy). @intel-volume3[kap. 18.2] Jak nastavit DR7, aby došlo k \#BP na spuštění instrukce ze vstupní adresy je už mimo rozsah tohoto textu, ale ve zkratce, jde o aktivování breakpointu a nastavení, aby vyvolal \#BP na spuštění instrukce. #footnote[V hardwarových breakpointech lze program přerušit i na čtení a zápis ze zadané adresy, *extrémně* užitečné pro ladění.] Rust má slibně vypadající balíček `x86` s modulem `debugregs`, #footnote[https://docs.rs/x86/latest/x86/debugregs/index.html] který umí automatizovat většinu práce složitého nastavování bitů.


=== Čtení mapovaných regionů paměti <memory-maps>
Aby vytvoření breakpointu nebylo až moc jednoduché, musíme ještě získat správnou adresu. Vstupní adresa je relativní ke startu ELF souboru, ale nikoliv k adrese v paměti. Při `execve` kernel načte celý program do paměti a ačkoliv program může přímo pracovat s relativními adresami, pokud chceme zapsat do paměti sledovaného, musíme získat _reálnou virtuální_ adresu.
vlajky
Kernel drží v `procfs` soubor `maps` pro každé #abbr.a[PID], který obsahuje mapované oblasti paměti pro proces. Jeho formát je popsaný v manuálové stránce pro `proc_pid_mem`, nicméně ve zkratce obsahuje rozsah virtuální adresy a její posun od relativní. Když chceme převést relativní adresu na virtuální, stačí vzít posun, který bereme jako start daného záznamu a přičíst k němu rozsah, který po součtu bereme jako konec oblasti záznamu. Pokud je naše adresa mezi začátkem a koncem záznamu, stačí pouze přičíst naši adresu ke adrese startu rozsahu. Pokud naše adresa není mezi koncem a začátkem, pokračujeme k dalšímu záznamu. @proc-pid-mem

V práci jsem tedy musel načíst vstupní adresu ELF souboru, poté ji převést na virtuální adresu, nastavit na ni instrukci `0xCC` a po její aktivaci nahradit za původní byte. Výsledkem tohoto je, že BouboTrace umí přeskočit počáteční kroky spouštění programu.

== Sledované systémové volání
BouboTrace umí korektně načíst minimálně následující systémové volání: `openat`, `read`, `write`, `close`, `socket`, `bind`, `listen`, `accept` a `exit_group`. U těchto volání jsou uloženy jména, podstatné hodnoty v parametrech, parametry s načtenou pamětí a návratová hodnota. U všech ostatních volání je uloženo jejich číslo, všechny možné registry s parametry a návratová hodnota. @syscall-load-difference znázorňuje rozdíl ve čtení mezi podporovaném a nepodporovaném systémovém volání.

#figure(
  ```
  Unknown { id: 11, args: SyscallArgs(129295288074240, 237451, 129295288569856, 140728277551152, 0, 129295288562432), return_value: 0 }

  Openat { dirfd: -100, pathname: [116, 101, 115, 116, 46, 116, 120, 116, 0], flags: OFlagSer(OFlag(O_CREAT | O_RDWR | O_TRUNC)
  ```,
  caption: [Rozdíl mezi podporovaném a nepodporovaném systémovém volání]
) <syscall-load-difference>

Specifické volání jsem v implementaci prioritizoval, protože se jedná o často volané volání, které hrají roli pro sledování chování programu. `read` a `write` slouží ke všeobecnému zápisu, `socket`, `bind` a `listen` jsou určené na sockety a zejména komunikaci po síti a nakonec je zde `exit_group`, kterým každý program musí končit. Některé systémové volání, jako `mmap`, jsou volané častěji než ty, které jsem prioritizoval, nicméně jejich sledování není až tak klíčové pro sledování, co program dělá.

Přidat implementaci pro chybějící volání už není tak složité, jelikož základní struktura pro čtení parametrů je už ve struktuře `Tracee`. Nejsložitější je zpravidla čtení příznaků a případně obstarat speciální chování nějakého volání.


== Serializace dat
Implementace serializace dat jsem udělal přes balíček `serde`, který nabízí serializaci do různých formátů. V tomhle případě jsem zvolil #abbr.a[JSON].

Aby struktura mohla být serializována, používá se zpravidla `serde::Serialize` makra. V ideálním případu stačí tohle makro aplikovat na strukturu a vše jde najednou lehce serializovat, bohužel, reálný svět takový není, protože používat makra můžeme pouze na vlastní struktury. BouboTrace používá na mnoha místech struktury z jiných knihoven, třeba pro `openat` příznaky. V práci jsem pro tyto typy implementoval tzv. newtype návrhový vzor, kdy je typ z cizí knihovny obalen v lokálním typu a pro tento typ jsem napsal ručně `Serialize` implementaci. V práci je tak obalen každý typ, který to vyžadoval.

Pro testovací účely jsem napsal jednoduchý iterátor, který načte všechny data do vektoru a serializuje. Výsledkem byl #abbr.a[JSON], který dle mého názoru nebyl moc dobře čitelný, protože používal `Ok` a `Error` z `Result` jako typy pro hlavní klíč. Mnohem větší smysl za mě dávalo mít jako hlavní klíč jméno volání a pak nějaké pojmenování pro chybu. Tím jsem se dostal k výsledné struktuře, která je ve @final-json[Výpisu].

#figure(
  ```json
  [
    {
      "close": {
        "fd": 3
      }
    },
    {
      "exit_group": {
        "status": 0
      }
    },
    {
      "syscall_error": "tracee process is not running and exited with status code 0"
    }
  ]
  ```,
  caption: [Finální podoba serializovaného #abbr.a[JSON]],
) <final-json>

Pro vytvoření takové serializace jsem musel vytvořit vlastní `Result` strukturu a vytvořit pro ni serializaci. Implementoval jsem pro ni i `From` trait, aby původní iterátor šel lehce převést do kontejneru této nové struktury. @syscall-wrapper ukazuje jak definici celého nového typu, tak i převod z typu používaného knihovnou.

#figure(
  ```rust
  #[derive(serde::Serialize)]
  #[serde(untagged)]
  enum SyscallWrapper {
      Syscall(Syscall),
      Error { syscall_error: SyscallParseError },
  }

  impl From<Result<Syscall, SyscallParseError>> for SyscallWrapper {
      fn from(value: Result<Syscall, SyscallParseError>) -> Self {
          match value {
              Ok(syscall) => SyscallWrapper::Syscall(syscall),
              Err(syscall_error) => SyscallWrapper::Error { syscall_error },
          }
      }
  }

  fn main() {
      // ...
      let v: Vec<SyscallWrapper> =
          called_syscalls.into_iter().map(From::from).collect();
      // ...
  }
  ```,
  caption: [Obalovací typ pro `Result` pro systémové volání včetně převodu z vektoru `Result`],
) <syscall-wrapper>

== Testování
// TODO dopsat testy z evaluace

= Evaluace implementace
V této kapitole se podíváme na funkčnost výsledného řešení. Jedním z cílů BouboTrace bylo zaručit, aby trasované programy jely tak, jako by nebyly trasované. K tomu je klíčové, aby trasování nebylo nějak ovlivněno a aby bylo rychlé.

== Bezvadnost <correctness>
Sledovatel by neplnil jeho práci moc dobře, pokud by omezil funkci sledovaného. Je tedy klíčové, aby BouboTrace zasahoval do funkčnosti sledovaného co nejméně. V rámci tohoto testování jsem postupoval jednoduše, prostě jsem spustil nějaký větší program a sledoval, jak se chová.

První problém jsem objevil ve webovém prohlížeči Chromium. Z nějakého důvodu Chromium na mém systému se vždy ukončí se signálem SIGSEGV. V té době jsem neměl zprovozněné předávání signálů (rozebrané v @ptrace-syscall[Kapitole] a implementované v @tracee-struct[Kapitole]). Co se tedy na konci stalo bylo, že sledovaný (zde Chromium) neustále dokola spouštěl instrukci, která doručila SIGSEGV. #footnote[#abbr.a[CPU] vrátí čítač instrukcí nad adresu před instrukcí, která vyvolala chybu (v tomhle případě page fault, kterou pak kernel doručí jako SIGSEGV). @intel-volume3[kap. 6.5]] Tento signál byl doručen sledovateli, ale nikdy nedorazil sledovanému. Sledovatel jenom pokračoval s exekucí sledovaného a tak pořád dokola. Řešením bylo uložit všechny získané signály a pak je později doručit. V případě SIGSEGV, pokud daný proces nemá k němu signal handler, tak obdrží SIGKILL a je ukončen.

Zkoušel jsem pak i různé další programy, jako Firefox, Dolphin, Darktable, GIMP, Krita, VLC a jiné. U žádného z nich jsem nezaznamenal nějaký problém během toho, co byl trasován. Je ale dobré zmínit, že BouboTrace nepodporuje sledování více vláken naráz, sleduje pouze jenom hlavní (viz @support-threads).

== Rychlost
// TODO otestovat rychlost
Jedním z důvodů, proč jsem zvolil jazyk Rust, byla právě rychlost.

== Pokrytí systémových volání
// TODO dopsat a změřit data pro tohle

= Možnosti rozšíření
Bohužel, čas na bakalářskou práci je limitovaný, a to znamená, že ne na každý nápad je čas. Proto se v této kapitole podíváme na prvky práce, které jsem nestihl nebo nezvládl dokončit nebo začít.

== Sledování více systémových volání
Systémových volání v Linuxu je _extrémně *hodně*_ a realisticky jsem je nemohl všechny implementovat pro tuhle práci. Nicméně pro úplnou funkčnost by bylo nezbytné implementovat minimálně ty, které provádí nějakou manipulaci s vnějším světem (není úplně nutné sledovat třeba `poll`, ale je důležité sledovat např. `creat`, `mmap`, `mprotect`, `ioctl` a další). V rámci práce jsem nicméně implementoval všechny nutné základy pro jednoduché přidávání dalších volání (zejména kopírování z paměti sledovaného, ale i celá `ptrace` infrastruktura).

== Podpora vláken <support-threads>
V současném stavu BouboTrace sleduje jenom jedno vlákno procesu. Je známo, že se zavolal `clone`, `fork` nebo `execve`, ale tato informace není nijak využita a druhé vlákno není sledované. Vzhledem k tomu, že BouboTrace má být ke sledování velkých programů, které *používají* vlákna, je tato funkcionalita nesmírně užitečná pro reálné využití. `ptrace` obsahuje možnosti pro automatické sledování dětí sledovaného, jde jenom o to v nich provést přeskočení do `main` funkce, pokud třeba, a sledovat veškerou akci v nich (ideálně paralelně) společně s hlavním procesem. Myšlenkově nejde o moc složité téma, implementačně ano.

== Rozbalení zásobníku
Představme si situaci, kdy se zpětně díváme na seznam volání nějakého programu a vidíme, že udělal `write`, který vypsal nějaký text do konzole. Bylo by extrémně užitečné vědět, který řádek našeho kódu tohle volání udělal. ELF soubor může obsahovat ladící symboly, které umožňují vytrasovat danou instrukci k řádku kódu. Problém je, že je k tomu potřeba ve většině případů rozbalit zásobník.

Rozbalením zásobníku se rozumí, že po něm putujeme nahoru po stopách zavolaných funkcí. Každé volání funkce vytváří na zásobníku nový rámec začínající adresou předchozího volání. Pokud tedy v našem kódu zavoláme `printf` a v něm se zavolá `write`, stane se tak v rámci `printf` a ne v našem rámci, tudíž současná adresa není uvnitř našeho kódu a nemůžeme přečíst část, kde byl zavolaný `printf`. Řešení je zde putovat po zásobníku, než dorazíme do bodu, kdy se `printf` zavolal. @intel-volume2[kap. 3.3]

V praxi tohle udělat správně je šíleně komplexní záležitost. Existuje na to několik řešení a balíčků, nicméně jsem se nedostal k žádnému z nich. Pokud bych někdy tuto funkcionalitu implementoval v potencionálním rozšíření BouboTrace, jednalo by se o takovou _hlavní věc, která jinde není_, #abbr.a[GDB] sice umožňuje zastavovat na systémových volání, ale extrémně blbě se to filtruje.

== Testování
Testování je v základní fázi v BouboTrace udělané za pomocí snapshotů za pomocí balíčku `insta`. #footnote[https://docs.rs/insta/latest/insta/]. Proces testování funguje na `Debug` výpisu vektoru se systémovými volání a chybami, kdy se jeho obsah porovnává vždy s předchozím testem a zjišťují se rozdíly mezi nimi. Ty se pak můžou schválit jako platné, nebo vrátit zpátky jako chyba. Tento postup je výborný jak pro programy postupně přidávající funkcionalitu, tak i pro programy testující, co se změnilo po nějakých úpravách.

Snapshot testing v BouboTrace funguje jak má a celý proces je (včetně překladu testovacích souborů) automatizovaný. První problém je, že se porovnává `Debug` výpis, což není úplně ideální a mnohem větší smysl by dávalo porovnávat serializovaný #abbr.a[JSON]. Druhý problém je, že velice hodně parametrů systémových volání se mění s každým během programu. `openat` vrátí jiný file descriptor. `socket` dá jiné číslo socketu. `mprotect` pracuje s jinou adresou v paměti. A tak dále. Řešením zde by bylo přidat do testů ignorování pro určité hodnoty. `insta` tuto funkcionalitu má, ale použít ji korektně pro každý test tak, aby se stále testovalo všechno nezbytné, je komplikované.

== Držení informací o současném stavu
V situaci, kdy program běží by se nebylo špatné zeptat BouboTrace, co má aktivně otevřené a co používá. V praxi na tohle existují už jiné nástroje, které tuto práci zvládají dobře (např. `lsof` a `htop`), nicméně nebylo by špatné mít všechno na jednom místě a i s případnou historií. Nejedná se rozhodně o tak podstatně chybějící funkcionalitu, jako rozbalování zásobníku, ale nazval bych ji jako _nice-to-have_.


= Závěr
// TODO zmínit testy
V rámci této práce jsem popsal důvody, proč současné řešení nestačí na sledování komplexních programů a zavítal do této problematiky snahou o implementaci takového nástroje. Implementovaný nástroj umí snímat systémové volání, serializovat je do souboru a skočit v ELF souboru až do relevantní části. Je v něm i kompletní #abbr.a[CLI] s možností nastavit některé atributy chování programu. Nástroj je postaven tak, aby byl velice rozšířitelný o všechny původně zamýšlené funkcionality.

Je zde spousta chybějících funkcionalit, které mám v plánu do budoucna přidat, primárně se jedná o vlákna a rozbalení zásobníku. Během práce jsem se dozvěděl extrémně moc nových věcí o funkčnosti x86 procesorů, Linux kernelu a i programovacím jazyku Rust.

#bibliography(
  "bibliography.yml",
  // this style is required by the styleguide
  style: templFolder + "iso690-numeric-brackets-cs.csl",
)

// Start appendix
#show: temp.appendix

= Obsah přílohy
// TODO dopsat

= Spouštění a používání BouboTrace
Nástroj BouboTrace využívá systému Cargo, které obsahuje spoustu funkcionalit pro správu programů. Pro spuštění BouboTrace v release módu stačí ve složce s `Cargo.toml` souborem spustit příkaz `cargo run -r`. Pro zadání argumentů je potřeba přidat dvě pomlčky, takže pro zadání `--help` napíšeme `cargo run -r -- --help`.

Po spuštění s `--help` vypíše program uživateli nápovědu, nicméně pokud chceme nastavit pracující složku na `work_dir`, vypsat každou hlášku, uložit výsledek do souboru `out.json` a spustit program `a.out`, zadáme následující příkaz: `cargo run -r -- -w work_dir/ a.out -vvv -o out.json`. BouboTrace kontroluje všechny špatně zadané cesty a vypíše v daném případě chybovou hlášku.

