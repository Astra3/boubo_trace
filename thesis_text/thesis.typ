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
    Cílem této bakalářské práce je navrhnout a implementovat prototyp nástroje, který sleduje programy v operačním systému Linux. Výsledný záznam je možné uložit do souboru. V textu práce jsou také popsaný základní koncepty sledování procesů a systémových volání. Ke konci je provedena evaluace implementace a také možnosti její rozšíření do budoucna.
  ],
  [
    The goal of this Bachelor's thesis is to design and implement a prototype of a tool, that allows tracing programs in Linux operating system. The resulting trace can be saved in a file. This text also describes basic concepts of process tracing and system calls. Towards the end, evaluation of the implementation is discussed, together with options to further expand it.
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
#temp.listSymbols((
  ("GDB", "GNU Debugger"),
  ("CPU", "Central Processing Unit"),
  ("OS", "Operační systém"),
  ("PID", [Process identification]),
  ("FFI", "Foreign Function Interface"),
  ("API", "Application Programing Interface"),
  ("CLI", "Command line interface"),
))

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

= Úvod
Při psaní programů, ať už v jakémkoliv paradigmatu nebo jazyce, každý programátor eventuálně řeší nějaký logický problém v programu. Tyhle problémy sahají od tlačítka, které z nějakého důvodu nic nedělá, až po finančně několika miliardové chyby. Pro zabránění, pochopení a prevenci těchto problémů byla vytvořena řada nástrojů a postupů. I přes jejich nepřeberné množství je stále možné najít nějakou nevyplněnou díru, postup nebo nástroj, který ještě nebyl vytvořen a správně vyzkoušen.

Sledování a pochopení fungování velkých programů vyžaduje velké úsilí a neexistují pro to žádné specificky určené nástroje, alespoň o kterých bych věděl. #footnote[Existující alternativy jsou více rozebrané v @existing-solutions[Kapitole].] Proces pochopení složitého programu trvá velice dlouho a dokáže být extrémně náročný na programátora.

Cílem práce je napsat nástroj a pochopit principy, jež by ulehčily analýzu programů, které prostě a jednoduše dělají až moc věcí. Kvůli potencionální složitosti takového řešení se v této práci podíváme pouze na základní kameny takového nástroje, nicméně jsem otevřen tento nástroj do budoucna dále rozvíjet.

V úvodních kapitolách se podíváme na principy zejména z operačních systémů, od popisu systémových volání až po `ptrace`. Následně si ukážeme existující nástroje a jejich dobré a chybějící vlastnosti relevantní pro větší programy. Po těchto základních věcech se dostaneme konečně k samotné implementaci nástroje BouboTrace a její evaluaci a na závěr si všechno shrneme.

= Principy systémových volání
Moderní operační systémy izolují procesy v nich běžící od přímého přístupu k hardware. K tomu, aby proces mohl získat nějaké data z hardware, požádá o ně operační systém přes systémové volání. Způsob spouštění a předávání argumentů systémových volání se liší podle OS a podle architektury CPU, #footnote[V případě x86-64 se k tomu dá použít instrukce `SYSCALL`. Parametry jsou předávány přes CPU registry. @intel-volume3[kap. 5.8.8] @syscall] nicméně ve valné většině případů existují knihovní procedury pro jazyk C (pro Linux se tato knihovna jmenuje `libc`) umožňující volat systémové volání. @tanenbaum-operating[kap. 1.6] Ve @write-example[Výpisu] lze vidět, jak můžeme využít jazyk C k použití systémového volání `write` k výpisu na standardní výstup.

#figure(
  raw(read("source_codes/write_example.c"), block: true, lang: "C"),
  caption: [Využití systémového volání `write` v C],
) <write-example>

Systémové volání zpravidla obsluhují I/O, nicméně může jít i o více komplikované věci, třeba uzamykání určitých oblastí paměti. #footnote[Viz #link("https://man7.org/linux/man-pages/man2/mprotect.2.html")[manuálová stránka pro `mprotect`].] Pro účely této práce jsou taky skvělý způsob jak zjistit, co program reálně dělá.

Parametry knihovní procedury se ne vždy shodují s parametry systémového volání. #footnote[`clone` systémové volání má jiné parametry, než procedura; tyhle parametry se liší i mezi architekturami. @clone] Stejně tak název procedury není nutně systémové volání, které daná procedura zavolá. #footnote[Zde tomu je třeba u systémového volání `fork`, `libc` procedura volá místo něj `clone`. @fork] @fork @clone


== Systémové volání `ptrace`
<ptrace-syscall>
Ačkoliv existuje velký počet způsobů, jak sledovat nějaký proces, v POSIX-ových operačních systémech je nejnižší a nejrychlejší cestou systémové volání `ptrace`.

#figure(
  ```c
  long ptrace(enum __ptrace_request op, pid_t pid, void *addr, void *data);
  ```,
  caption: [Parametry systémového volání `ptrace` @ptrace],
) <ptrace-params>

Definice knihovní procedury a systémového volání `ptrace` je ve @ptrace-params[Výpisu]. Její parametry jsou následující:
#argument_list(
  "op",
  [Definuje operaci pro `ptrace`. Patří mezi ně třeba `PTRACE_GETREGS`, `PTRACE_POKETEXT`, atd.],
  "pid",
  [PID procesu, na kterém chceme provést `op`.],
  "addr",
  [Použití tohoto parametru se liší dle `op`.],
  "data",
  [Použití tohoto parametru se liší dle `op`.],
)

Návratová hodnota záleží na `op`, některé operace vrací vyžádané data a některé jenom 0. Všechny nicméně vrací -1, pokud dojde k chybě.

Proces, který používá `ptrace` na jiný proces (tzn. že zadává jeho PID do `pid` parametru) se nazývá "tracer" (sledovatel) a proces, který je sledován sledovatelem se nazývá "tracee" (sledovaný). Pojmy "sledovatel" a "sledovaný" budou nadále používány v práci. Aby sledovatel mohl monitorovat sledovaný proces, musí sledovaný nejprve zavolat `ptrace(PTRACE_TRACEME)` a musí být potomkem sledovatele. #footnote[Tohle není nutně vždy pravda. `ptrace` má nastavitelné přístupové módy a můžou být jak více volné, tak i více limitující až kompletně zakázaný. @ptrace]

=== Příklad inicializace `ptrace` <ptrace-example-chapter>
#figure(
  raw(read("source_codes/ptrace_example.c"), block: true, lang: "C"),
  caption: [Ukázka připojení k procesu přes `ptrace`],
) <ptrace-example>

Ve @ptrace-example[Výpisu] lze vidět základní nastavení používání `ptrace`. Nejprve je zavolána procedura `fork`, která zkopíruje vše o současném procesu do nového procesu, který je potomek současného procesu. Novému procesu (dítěti) dá návratovou hodnotu 0, rodiči vrátí PID dítěte. @fork Dítě potom zavolá `ptrace` s `PTRACE_TRACEME` operaci, díky které (1) dovolí rodiči dělat na daném procesu `ptrace` operace (2) zastaví samo sebe. Rodič tedy čeká (za pomocí systémového volání `waitpid`), než se dítě zastaví a jakmile je zastaveno, tak pokračuje #footnote[V korektní `ptrace` terminologii je sledovaný restartován.] s jeho spouštěním.


=== Práce se signály <ptrace-signals>
Pokud sledovaný obdrží nějaký signál, tento signál mu nikdy není doručen. Místo toho je tento signál doručen přes systémové volání `waitpid` sledovateli. Je na sledovateli, jestli tento signál předá sledovanému (např. přes parametr `data` v operaci `PTRACE_CONT`) anebo zda ho nějak jinak zpracuje. Výjimku v tomto chování tvoří `SIGKILL`. @ptrace

=== Nastavení `ptrace`
`ptrace` umožňuje provést nějaké nastavení, kde ty podstatné možnosti pro tuhle práci jsou popsány v @ptrace-options[Tabulce]. Hodně z nich upozorňuje na volání nějakého systémového volání, které díky tomu, že program v implementaci sleduje systémové volání tak či tak, nejsou nutně potřeba.

#figure(
  table(
    columns: (auto, auto),
    [*Nastavení*], [*Popis*],
    [`PTRACE_O_TRACEEXEC`], [Informuje sledovatele o tom, že sledovaný zavolal `execve`],
    [`PTRACE_O_TRACEFORK`], [Informuje sledovatele o tom, že sledovaný zavolal `fork`],
    [`PTRACE_O_EXITKILL`], [Zabije sledovaného, pokud sledovatel ukončí jeho běh]
  ),
  caption: [Popis možností v `ptrace`]
) <ptrace-options>

== Systémové volání `process_vm_readv` a `process_vm_writev` <process-vm-chapter>
Abychom mohli přečíst argumenty, které byly předány do systémového volání a ukazují na nějaké data v paměti sledovaného, musíme zkopírovat paměť ze sledovaného do sledovatele. Jsou celkem tři způsoby, jak tohoto dosáhnout: @trnka-thesis[kap. 4.2]

+ `ptrace(PTRACE_PEEKTEXT)` a `ptrace(PTRACE_PEEKUSER)` #footnote[`PTRACE_PEEKUSER` vrací data z `USER` části paměti, obsahující např. registry a informace o procesu.] -- Výhodou těchto volání je, že jsou velice jednoduché na použití. Stačí zadat adresu, ze které chceme číst a přečtená hodnota je vrácena jako návratová hodnota. Nevýhodou je, že lze číst pouze po jenom hardwarovém slově, tedy pro každé hardwarové slovo je potřeba udělat jedno volání. Ve výsledku je to poměrně efektivní řešení pro data o velikosti jednoho slova (např. registry), ale velice neefektivní pro větší data (např. řetězce).
+ Soubor `/proc/pid/mem` -- PID nahrazujeme za PID procesu; jedná se o klasický soubor, který obsahuje paměť daného procesu. Pracuje se s ním, jako s klasickým souborem, tudíž ho nejdříve otevřeme přes `open()` a poté přes `lseek()` #footnote[Systémové volání `open` a `lseek` lze nahradit za funkce v C standardu (`fopen` a `fseek`).] se přesuneme na adresu, kterou chceme číst. Nakonec použijeme `read` pro čtení adresy. @proc-pid-mem Jak si můžete všimnout, nevýhoda tohoto postupu je, že zahrnuje poměrně dost kroků a systémových volání pro čtení jedné adresy, nicméně oproti první metodě pro větší množství dat vyžaduje méně systémových volání.
+ `process_vm_readv`/`process_vm_writev` -- Systémové volání, které umožňují kopírovat přímo paměť mezi dvěma procesy. Výhodou je, že volání kopíruje data přímo mezi procesy (data nejdou přes kernel). Umožňují taky poměrně komplexní způsoby kopírování. @process_vm Nevýhodou je komplexnost použití, nicméně primárně díky rychlosti těchto systémových volání jsem je vybral jako způsob pro kopírování paměti ze sledovatele do sledovaného.

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
  [PID procesu, ze kterého chceme číst.],
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
Programovací jazyk Rust je tzv. "memory-safe" nízkoúrovňový systémový jazyk, který klade důraz na výkon, souběh a typovou bezpečnost. Nepoužívá ani garbage collector; místo toho používá "borrow checker," který kontroluje platnost referencí a dobu jejich života během překladu. Všechny proměnné jsou také ve výchozím stavu "non-mutable," tzn. že nelze přepsat jejich obsah. Půjčuje si hodně vzorů z funkcionálních jazyků, nicméně objevuje se v něm i pár konceptů z OOP. Protože v nízkoúrovňovém prostředí nemůže být úplně všechno bezpečné, umožňuje jazyk Rust některé pravidla obejít v `unsafe` blocích. @rust-astrophysics[kap. 2].

Jazyk Rust používá systém Cargo pro správu testů, parametrů překladu, verze programu a mnoho dalšího. Jedním z konceptů v Cargo je "crate," jedná se o nějaký zdrojový kód, který je dostupný lokálně nebo z internetu a jakmile je přidaný do současného projektu, je možné importovat jeho veřejné členy v současném projektu. @rust-book[kap. 7]

Rust rovněž umožňuje propojení s jinými nízkoúrovňovými programovacími jazyky za pomocí FFI. Je tedy možné poměrně jednoduše volat funkce z C nebo C++. Všechny funkce definované přes FFI jsou ve výchozím stavu unsafe, nicméně lze kolem nich udělat bezpečné obaly, jak je tomu ve @ffi-example[Výpisu]. @rustonomicon[kap. 11]

#figure(
  raw(read("source_codes/ffi/src/lib.rs"), block: true, lang: "rust"),
  caption: [Ukázka použití knihovny `snappy` přes FFI v jazyce Rust. @rustonomicon[kap. 11]],
) <ffi-example>

Jazyk Rust byl zvolen pro tuhle práci zejména díky, dle mého názoru, skvělému syntaxu. Rychlost a bezpečnost už jsou jenom takové třešničky na dortu.

== Enum
Enum v jazyce Rust funguje podobně jako enum v jiných programovacích jazycích, akorát každá položka může obsahovat vlastní data. Příklad takového enumu je ve @enum-example[Výpisu]. Standardní knihovna obsahuje enumy `Result` a `Option`, kde první může vyjádřit úspěch nebo chybu a druhý existující nebo prázdné data. @rust-book[kap. 6.1].

#figure(
  ```rust
  enum Example {
      First(u8, u8),  // obsahuje 2x u8
      Second {  // obsahuje vektor bytů a nějaký popis
          bytes: Vec<u8>,
          description: String
      },
      Third,  // varianta neobsahuje žádné data
  };
  ```,
  caption: [Ukázka enum v jazyce Rust],
) <enum-example>


== Balíček `nix`
Balíček `libc` obsahuje všechny FFI definice pro systémové volání v Linuxu. Balíček `nix` kolem nich dělá bezpečné obaly. Rozdíl definice `write` mezi `libc` a `nix` balíčky je zobrazený ve @write-difference[Výpisu]. Mezitím co `libc` implementace mapuje `write` přímo, `nix` obal se ptá na typ z Rustu a vrací typ `Result`, který vynucuje programátora ošetřit vrácené chyby. To je hlavní a primární rozdíl mezi jak `libc` definicí, tak přímého volání z C.

#figure(
  ```rust
  // libc
  pub unsafe extern "C" fn write(fd: c_int, buf: *const c_void, count: size_t) -> ssize_t
  // nix
  pub fn write<Fd: AsFd>(fd: Fd, buf: &[u8]) -> Result<usize>
  ```,
  caption: [Porovnání systémového volání `write` mezi `nix` a `libc`. @libc-rust @nix-rust],
) <write-difference>

Pro (zatím) všechny přímé systémové volání jsem v práci byl využil balíček `nix`. Některé potencionálně užitečné definice v něm někdy nejsou nadefinované, #footnote[Příkladem zde je operace `PTRACE_GET_SYSCALL_INFO`. Je dostupná v `libc`, ale v `nix` zatím nebyla implementována. Je o tom již dlouhodobě aktivní PR: https://github.com/nix-rust/nix/pull/2006.] nicméně dá se bez nich většinou obejít a případně zavolat přímo přes `libc`.


= Existující alternativy <existing-solutions>
V této kapitole se podíváme na existující alternativy k řešení. U každé z nich je uveden krátký popis včetně toho, proč je její použití vhodné či nevhodné.

== strace <strace-solution>
`strace` je velice populární nástroj na analýzu systémových volání programu. Umí spustit nějaký program a vypsat všechny systémové volání, které provedl, a to včetně návratových hodnot. @strace Nevýhodou je komplexnost výstupu. I v případě jednoduchých programů, jako lze vidět ve @open-example[Výpisu], který používá celkem tři systémové volání, vrátí `strace` hromadu jiných systémových volání, které nejsou součástí reálného programu. #footnote[Tohle je z toho důvodu, že v ELF formátu se provede několik systémových volání před vstupem do samotného programu. Více je tohle rozebrané v @skip-to-main[Kapitole].]

#figure(
  raw(read("source_codes/open.c"), block: true, lang: "c"),
  caption: [Jednoduchý program používající `open` systémové volání],
) <open-example>

Další nevýhodou `strace` je čistá komplexnost výstupu u velkých programů. Zejména jakmile program začne pracovat s vlákny, může být analýza výsledného výstupu velice matoucí a může být obtížné v ní něco najít. `strace` je skvělý nástroj na rychlou opravu chyby (třeba když systémové volání vrátí chybu, kterou daný program neodchytil), ale rozhodně ne na rozsáhlou analýzu a pochopení programu.

== intentrace
intentrace #footnote[https://github.com/sectordistrict/intentrace] je nedávno zveřejněný nástroj v beta verzi, který má za úkol zjednodušit čtení `strace`. Ačkoliv tohle nástroj dělá výborně, přichází na stejné problémy, jako `strace` -- výstup obsahuje až moc informací.

== Krokování přes GDB nebo LLDB
Krokování je běžným způsobem diagnostiky chyb chování programu. Umožňuje nám postupně procházet určitě části programu a dívat se, co je s nimi špatně nebo dobře. Problém krokování je, že umí nakreslit pouze části do puzzle chování programu, nikoliv celé puzzle. Skládání puzzle je už na programátorovi. Tento postup funguje, když má puzzle 100 dílků; když jich má 50~000, nefunguje už tak moc dobře.


= Implementace nástroje BouboTrace <implementation>
V této kapitole se nejprve podíváme na strukturu kódu v BouboTrace a poté si něco řekneme o věcech, které byly dokončeny a jaké problémy to obnášelo. V celé kapitole se probírá pouze x86-64 instrukční sada a architektura, pokud není zmíněno jinak.

== Struktura BouboTrace
BouboTrace obsahuje několik komponent, které dohromady tvoří celý nástroj. Program je rozdělený na knihovní a aplikační kód, kdy knihovní kód se stará o čtení systémových volání a aplikační kód o spuštění sledovaného programu a CLI.

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

Ze začátku tento postup fungoval skvěle, nicméně eventuálně jsem narazil na problém chyb; uživatel by měl být informován o chybách, knihovní kód by si je neměl nechávat pro sebe. Mezi možné chyby patří nějaká chyba z `ptrace` (např. když je daný region paměti uzamknut, proces s daným PID neexistuje atd.), ale i chyba ze systémového volání (více popsáno v @syscall-errors[Kapitole]). Jako chyby jsou předávány i různé události (třeba ukončení procesu). Finální typ iterátoru je tedy `Result<Syscall, SyscallParseError>`, uživatel je tak informován o všech chybách a událostech. Příklad finálního čtení iterátoru je ukázán ve @final-interface[Výpisu].
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

=== Struktura `Tracee` <tracee-struct>
Struktura `Tracee`, která je definovaná v souboru `tracee.rs`, představuje obal nad `ptrace` rozhraním z balíčku `nix`. Je to z toho důvodu, že některé složitější operace v `ptrace` jsou poměrně časté, chtěl jsem nad nimi tedy nějaký obal, abych pro jejich úpravu nemusel měnit kód na několika místech. `Tracee` rovněž enkapsuluje PID sledovaného, nelze tedy přečíst ze zbytku knihovního kódu a všechny `ptrace` operace musí proběhnout přes metody `Tracee`.

`Tracee` obsahuje jak jednoduché metody (např. `read`, `write`, `read_rax` atd.), tak i složitější metody s náročnější logikou. Jednou z nich je třeba `memcpy_until`, která za pomocí `process_vm_readv` systémového volání kopíruje paměť ze sledovaného do sledovatele a každém bytu této kopírované paměti spouští předanou anonymní funkci. Pokud ta vrátí hodnotu `true`, tak je kopírování ukončeno. Mezi další metody patří třeba `strcpy`, která obaluje `memcpy_until`, dokud není načtení ukončovací znak. Podrobnější popis mých myšlenkových pochodů při psaní těchto metod je poskytnut v @syscall-loading[Kapitole].

Nakonec jsou zde i metody na `wait_for_stop`, `cont` a `syscall`. V @ptrace-signals[Kapitole] jsem ustanovil, že signály jsou vždy doručené sledovateli a nikoliv sledovanému. Je čistě na sledovateli (tedy nás), co s daným signálem dělat. Všechny doručené signály jsou doručené v `waitpid` systémovém volání, které je volané ve `wait_for_stop` metodě. Pokud je tedy sledovaný zastaven na nějakém signálu, je tento signál uložen ve struktuře a poté předán sledovanému při volání `cont` nebo `syscall` metody. Výjimku tvoří SIGKILL, jelikož ten kernel doručuje přímo sledovanému @ptrace a SIGTRAP, který signalizuje trap signál z CPU a je používaný pro nastavení breakpointu. Více je tohle rozebrané v @breakpoint-creation[Kapitole].

=== Enum `Syscall`
Enum `Syscall`, nacházející se v souboru `syscall.rs`, obstarává načítání všech implementovaných systémových volání. Obsahuje metodu `parse`, která vezme referenci na strukturu `Tracee`, na které byla zavolána metoda `syscall` a čeká, až se zastaví na vstupu do systémového volání. Poté načte všechny parametry systémové volání (čísla, řetězce, vlajky, pole, apod.), zavolá `syscall` metodu a poté přečte návratovou hodnotu.

Pokud během čtení dojde k nějaké chybě, ať už z `ptrace` nebo z návratové hodnoty systémového volání, vrátí metoda `parse` chybu ve formě typu `SyscallParseError`. Tento typ umožňuje zahrnout hromadu chyb a stavů, od chyby `ptrace` přes ukončení sledovaného až po chybu systémového volání. Je to taky typ, který je vrácen v iterátoru. Pokud čtení proběhne úspěšně, vrátí metoda instanci enumu `Syscall`, který obsahuje přečtené systémové volání.

=== Aplikační kód
Aplikační kód BouboTrace zahrnuje způsob, jak spustit sledovaného a taky CLI. Pro čtení parametrů z příkazové řádky jsem použil balíček `clap`, který umožňuje velice jednoduše číst argumenty v příkazovém řádku do struktur. Po přečtení parametrů, které zahrnují například úroveň logování, název spouštěného programu, jeho pracující složku a různé další věci, dojde ke spuštění sledovaného. Jak bylo zmíněno v @ptrace-example-chapter[Kapitole], pro inicializaci `ptrace` je potřeba, aby dítě zavolalo `PTRACE_TRACEME` operaci. Sledující musí tedy provést následující kroky:

+ Zavolat `fork` (nebo `clone`) a tím vytvořit kopii sama sebe.
+ V rodiči počkat na zastavení dítěte.
+ V dítěti zavolat `PTRACE_TRACEME` operaci.
+ V dítěti zavolat `execve` systémové volání, které nahradí daný program s programem zadaném v argumentu volání. Ve zkratce _nahradí_ současný program za jiný.

Jazyk Rust obsahuje ve standardní knihovně strukturu `Command`, která umožňuje spustit program jako dítě současného programu. Disponuje i unsafe metodou `pre_exec`, která obsahuje anonymní funkci, která se spustí v dítěti před samotným programem. Povedlo se mi nicméně najít balíček `spawn_ptrace`, #footnote[https://docs.rs/spawn-ptrace/latest/spawn_ptrace/] který celý tento proces dokáže automatizovat a chybově ošetřit.

== Čtení systémových volání
`ptrace` systémové volání, diskutované v @ptrace-syscall[Kapitole], obsahuje operaci `PTRACE_SYSCALL`. Tato operace zastaví sledovaného vždy při vstupu a výstupu ze systémového volání. Vzhledem k tomu, že nás primárně zajímají jenom systémové volání, je tato operace ideální, jelikož nabízí nejmenší komplexitu.

Sledovaný je zastaven vždy po volání systémového volání a pokud je poté restartován opět s `PTRACE_SYSCALL` operací, tak je opět zastaven těsně před východem ze volání. V prvním případě můžeme přečíst argumenty předané do systémového volání a jaké systémové volání proběhlo, #footnote[RAX obsahuje číslo systémového volání, když sledovaný volá `SYSCALL`; neobsahuje ho během systémového volání. Kernel nicméně ukládá původní hodnotu v `orig_rax` hodnotě v USER části paměti. Více o USER části v @breakpoint-creation[Kapitole].] v druhém případě návratovou hodnotu volání.

V x86-64 architektuře jsou parametry systémového volání předávané přes registry. @syscall Koncept kódu pro čtení parametrů a návratových hodnot všech systémových volání se nachází ve @ptrace-concept[Výpisu]. Proces operací je následující:

+ Zavoláme `PTRACE_SYSCALL` operaci na PID sledovaného
+ Počkáme, než se sledovaný dostane do zastaveného stavu
+ Přečteme parametry systémového volání z uživatelského regionu paměti sledovaného #footnote[`ptrace` k tomuhle nabízí `PTRACE_GETREGS` operaci, nicméně lze i číst z USER regionu paměti, jelikož tam jsou registry uloženy vždy při výměně procesu na CPU.]
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
Hlavní registry x86-64 jsou 64 bitové a v Linuxu jsou používané jako `i64` (v jazyce C `long`) datový typ. Jedná se tedy o 64-bitové číslo s dvojkovým doplňkem. Pokud systémové volání chce vrátit nějakou chybu (např. `openat` byl požádán o vytvoření souboru ve složce, ve které nemá práva), vrátí v RAX registru číslo chyby jako záporné číslo. V tomhle případě `openat` chce vrátit `EACCES`. Číslo #footnote[Pro zjištění čísla chyb je skvělý program `errno`, součástí moreutils.] `EACCES` chyby je $13$, tedy `openat` do RAX registru zapíše číslo $-13$.

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

Přečíst všechny číselné datové typy (`int`, `long`, atd.) je velice jednoduché, stačí pouze načíst hodnotu z daného registru a poté správně přetypovat. Problém nastává u ukazatelů, kdy musíme načíst adresu (a vědět, kolik z ní načíst) a u vlajek.

==== Čtení dat fixní délky
Pro načtení pole z paměti sledovaného v práci využívám systémové volání `process_vm_readv`, popsané v @process-vm-chapter[Kapitole]. Naštěstí u systémových volání s fixní délkou dat je délka dat předána v jiném parametru (v případě `write` jde o poslední). Pokud potřebujeme načíst strukturu, zjistíme si přes `std::mem::size_of::<T>()` funkci její velikost v bajtech a tu pak načteme.

==== Čtení dat variabilní délky
Nejčastějším příkladem čtení dat variabilní délky je C řetězec. #footnote[Jedná se o sekvenci bytů ukončenou bytem `0x00`.] V kernelovém prostoru je to, minimálně podle mých znalostí, jediná položka variabilní délky, proto se dále budu bavit pouze o ní. Celý proces jsem graficky znázornil v @chart-variable-loading[Obrázku].

Při načítání řetězce je třeba myslet na následující otázky:
- #underline[Kde je konec načítaných dat?]

  V případě C řetězce je tato odpověď poměrně jednoduchá, nicméně problém nastává v tom, že nemůžeme jednoduše číst paměť sledovaného (možnosti čtení jsem rozebral v @process-vm-chapter[Kapitole]) a provádět na ni hledání. Jedním z nápadů je si paměť sledovaného zkopírovat do sledovatele, jenže abychom tohle mohli provést, musíme znát délku dat. Řešením je tedy načítat data po částech do bufferu a v každé načtené části vyhledat ukončovací znak; jakmile je nalezen, data v té části uřízneme a považujeme za načtené.

- #underline[Může načtených dat být _až_moc_?]

  C řetězec nemá jasnou délku. Může obsahovat jak 10 bajtů, tak i 2 GiB. Kopírovat takový počet dat by bylo velice neefektivní. Řešením zde je nastavit tvrdou hranici kopírování, kdy počet zkopírovaných dat je _až moc_ velký. Pro tuhle práci jsem zvolil limit 2 MiB, dle mé znalosti ho ani jeden ze všech testovaných programů v @correctness[Kapitole] nepřekročil.

- #underline[Můžeme během čtení narazit na neinicializovanou paměť?]

  Ano, můžeme. Nicméně volání `process_vm_readv` v tom případě nevrací chybu, ale pouze načte méně dat. Že se tomu tak stalo je zjevné z návratové hodnoty, čili lze lehce detekovat, že byl proveden pokus o přečtení neplatné paměti. V tom případě ukončíme čtení.

- #underline[Obsahují načtené data reálně znaky řetězce?]

  V případě řetězců C cokoliv předpokládat je obrovská chyba. Jedná se o `char*`, kde `char` je jakékoliv 8bitové číslo, včetně neplatného znaku. Do toho kernel plně používá UTF-8, @linux-unicode čili co reálně sledovaný obsahuje za znaky leží většinou ve hvězdách. `String` a `str` struktury a typy v jazyce Rust nicméně vyžadují validní UTF-8, čili možné způsoby, jak uložit C řetězec v jazyce Rust jsou:
  + Pokusit se o kontrolu validity UTF-8 a uložit jako `String`
  + Využít strukturu `CString`
  + Pracovat s C řetězci jako s vektorem bytů, `Vec<u8>`
  V práci jsem se rozhodl pro poslední možnost, protože nabízela nejméně nevýhod.

#figure(
  image("sources/variable_reading.svg"),
  caption: [Diagram načítání dat variabilní délky],
) <chart-variable-loading>

==== Načítání vlajek
Binární vlajky jsou čísla, kde hodnota jednoho bitu značí nějaký přepínač. Ve @openat-flags[Výpisu] lze vidět použití těchto vlajek u systémového volání `openat`. V @openat-flags-desc[Tabulce] lze vidět popis použitých vlajek. Všimněte si, že binární hodnota vlajky obsahuje jiné bity pro danou vlajku. Přes logický OR tedy můžeme zkombinovat více vlajek do jednoho čísla, které pak můžeme předat jako číslo v parametru systémového volání. @flags-beauty

#figure(
  ```c
  int fd = openat("file.txt", O_CREAT | O_TRUNC | O_WRONLY, S_IRWXU);
  ```,
  caption: [Využití binárních vlajek u systémového volání `openat`],
) <openat-flags>

#figure(
  table(
    columns: (auto, auto, auto),
    align: left + horizon,
    table.header(
      [*Název vlajky*],
      [*Dvojková hodnota vlajky* #footnote[Jedná se o hodnotu vlajky na mém systému; může se lišit podle architektur]],
      [*Popis vlajky*],
    ),

    [`O_CREAT`], [`0001000000`], [Vytvoří soubor, pokud neexistuje],
    [`O_TRUNC`], [`1000000000`], [Pokud soubor existuje, vymaže při otevření veškerý jeho obsah],
    [`O_WRONLY`], [`0000000001`], [Otevře soubor pouze pro zápis],
  ),
  caption: [Popis vlajek použitých ve @openat-flags[Výpisu] @open],
) <openat-flags-desc>

Problém načítání vlajek je, že se jedná _pouze o číslo_. Pokud tedy chceme zjistit hodnotu vlajky, musíme z číselné hodnoty přečíst nastavené bity a pak zjistit, jaké nastavení každý bit reprezentuje. V C by tohle bylo poněkud obtížné, protože všechny možnosti jsou nadefinované jako makra a nelze je tudíž jednoduše převést během běhu programu do textové podoby. @flags-beauty V jazyce Rust záleží, z jakého balíčku vlajky bereme. Všechny makra převzaté z C jsou nadefinované v balíčku `libc` jako konstantní čísla, ve své podstatě se tedy chovají stejně, jako vlajky z C a jejich převod do textové podoby je obtížný.

Balíček `nix` nicméně používá vlastní implementaci balíčku `bitflags`. #footnote[https://docs.rs/bitflags/latest/bitflags/] Tento balíček umožňuje pracovat s vlajkami v ergonomickém API. Umožňuje jednoduše vlajky nastavit, ale hlavně vypsat a získat z čísla. Jak tohle vypadá v praxi ukazuje @oflag-flags[Výpis], kde je ukázka načítání vlajek (v praxi by se hodnota načítala z registru místo proměnné).

#figure(
  ```rust
  let flags = libc::O_CREAT | libc::O_TRUNC;
  let flags = fcntl::OFlag::from_bits(flags).unwrap();
  println!("{flags:?}");  // OFlag(O_CREAT | O_TRUNC)
  ```,
  caption: [Příklad inicializace `nix::fcntl::OFlag` vlajkové hodnoty],
) <oflag-flags>

#show link: it => {
  if type(it.dest) != str { it } else { emph(it) }
}

== Spuštění ve vstupním bodu <skip-to-main>
Při psaní v nízko úrovňových jazycích používáme zpravidla funkci `main` jako první věc, která se v programu spustí. Při překladu a linkování programu dochází k vytvoření souboru ve formátu ELF, který obsahuje jak přeložený kód, tak i nějaké informace k němu.

Pro spuštění programu se v Linuxu používá systémové volání `execve`. Jako první parametr přijímá cestu k souboru (zpravidla v ELF formátu #footnote[`execve` umožňuje volat přímo interpretry pro jazyky, které to vyžadují. Pokud třeba soubor, který začíná s `#!/usr/bin/bash` je předán do `execve`, je místo souboru přímo spuštěn `/usr/bin/bash` s cestou k souboru jako první argument.]). Pokud tento soubor vyžaduje dynamické linkování, je zavolaný interpreter pro načtení sdílených objektů (zpravidla `ld-linux.so`). @execve A tím je konečně vysvětlený můj problém s nástrojem `strace`, vysvětlený dávno v @strace-solution[Kapitole]. Jako první systémové volání ihned po `PTRACE_TRACEME` operaci bývá `execve` samotného programu a poté, pokud je ELF dynamicky linkovaný (víceméně úplně všechny), dochází k dynamickému linkování (což zahrnuje hromadu systémových volání). Až po tomhle všem doráží sledovaný do funkce `main`.

Formát ELF obsahuje několik sekcí,
#footnote[
  Obrázek znázorňující strukturu ELF je k dispozici
  #link("https://github.com/corkami/pics/blob/28cb0226093ed57b348723bc473cea0162dad366/binary/elf101/elf101-64.svg")[#underline[zde]],
  případně i ve
  #link("https://en.wikipedia.org/wiki/Executable_and_Linkable_Format#/media/File:ELF_Executable_and_Linkable_Format_diagram_by_Ange_Albertini.png")[#underline[Wikipedia stránce o ELF]].
]
kdy každá z nich obsahuje nějaké informace o programu. Pro nás největší význam tvoří položka `e_entry` (dále jako vstupní adresa), která se nachází v hlavičce ELF souboru. Tato položka značí adresu ve virtuální paměti,
#footnote[V tomto kontextu je virtuální paměť paměť relativní k danému ELF souboru, s tím, že adresa `0x0` odkazuje na start ELF souboru. @elf V praxi přístup k této adrese je složitější, více o tom v @memory-maps[Kapitole].]
která značí počátek instrukcí (kódu) v ELF souboru. @elf Pokud tedy program spustíme, necháme běžet, zastavíme ve vstupní adrese a až poté budeme sledovat systémové volání, přeskočíme tím všechny volání způsobené dynamickým linkováním.

Pro načtení vstupní adresy v jazyce Rust jsem použil balíček `elf`. #footnote[https://docs.rs/elf/latest/elf/] Do něj stačí předat ELF soubor, který můžeme najít přes `procfs` v souboru `exe` a provést minimální čtení ELF souboru. @proc-pid-exe Minimální čtení umožňuje přečíst obsah hlavičky, ve které se vstupní adresa nachází. Větší věda v tom naštěstí není.

=== Vytvoření breakpointu <breakpoint-creation>
Většina programátorů zná breakpoint jako řádek v kódu, kde se jejich program zastaví a oni mohou přečíst hodnoty proměnných za běhu. Pro účely jejich vytvoření musíme použít nicméně více konkrétní definici; breakpoint je v paměti sledovaného adresa, kam když dojde čítač instrukcí, #footnote[Anglicky také program counter nebo instruction pointer; obsahuje posun od počáteční adresy a posouvá se vždy po každé instrukci na začátek další instrukce. @intel-volume1[kap. 3.5.1]] tak sledovaný obdrží (zpravidla) SIGTRAP signál a je zastaven. Jak bylo zmíněno v @ptrace-signals[Kapitole], sledovaný nedostává žádné signály přímo, ale sledovatel je informován, že sledovaný nějaký signál obdržel.

První možnost, jak dosáhnout breakpointu, je použít `ptrace` operaci `PTRACE_SINGLESTEP`. Ta program posouvá vždy o jednu instrukci. Pokud bychom tedy opakovaně volali tuhle operaci a při každém volání se podívali na adresu v čítači instrukcí a porovnali ji se vstupní adresou ELFu, budeme informování přesně o bodu před začátkem našeho kódu. Tento postup nicméně obsahuje dva problémy. Zaprvé, RIP registr (čítač instrukcí) nelze číst.
#footnote[
  Registr RIP nelze číst..._přímo_. Pro nepřímé čtení lze použít nějakou instrukci, která skáče mezi adresami v paměti (např. `CALL`). Tyto instrukce vždy nahrají současnou hodnotu RIP do zásobníku a nahrají do něj jinou, nadefinovanou adresu. Instrukce `RET` pak ze zásobníku přečte první položku a nahraje ji do RIP registru. @intel-volume1[kap. 3.5] @intel-volume2
]
Zadruhé, volat `ptrace` pro krokování každé instrukce je velice neefektivní. Z obou těchto důvodu tohle řešení nepřipadá absolutně v úvahu, proto mnohem lepším řešením je vyvolat SIGTRAP ve správný čas a hlavně na správném místě.

Jak tedy vyvolat SIGTRAP na místě, kde ho potřebujeme? SIGTRAP signál je doručen, pokud na CPU dojde k breakpoint exception (\#BP). @signal Dle svaté bible všech x86-64 CPU, Intel 64 manuálu, je několik způsobů, jak \#BP vyvolat a pro nás jsou relevantní dva z nich.

==== Instrukce INT3
Instrukce INT3 (opcode `0xCC`) vyvolává \#BP. Má velikost přesně jednoho bytu, aby mohla nahradit celou nebo část jakékoliv instrukce. @intel-volume2[kap. 3.3] V praxi tedy byte na adrese, kde chceme udělat breakpoint, uložíme v paměti sledovaného, nahradíme ho za `0xCC` a jakmile zjistíme, že sledovaný obdržel SIGTRAP, nahradíme změněný byte za původní a pokračujeme ve spouštění sledovaného. INT3 generuje na CPU chybu kategorie trap, která posune RIP za adresu této instrukce.
#footnote[Původně jsem si myslel, že registr RIP není posunut při volání INT3. Příhodně ale skoro všechny ELF soubory začínají ve vstupní adrese instrukcí ENDBR64, která je při přeskočení prvního bytu převedena na NOP (instrukce, která nic nedělá). Slovo na ulici je, že Intel tohle udělal z důvodů zpětné kompatibility s procesory, které neimplementují ENDBR64. Přeskočením této instrukce je nicméně tak či tak narušena integrita programu a jednalo se o bug v BouboTrace.]
@intel-volume3[kap. 6.5] Registr RIP nicméně není přímo zapisovatelný.

`ptrace` umožňuje číst ze dvou regionů paměti: USER region a data programu. USER region obsahuje primárně registry, ale je v něm i pár věcí navíc. Abychom načetli něco z USER regionu, můžeme použít `PTRACE_PEEKUSER` operaci. Soubor `<asm/ptrace-abi.h>` obsahuje všechny posuny pro všechny GP registry. #footnote[General Purpose, hlavní programovatelné registry jako RAX, RBX, R8, atd.] Pokud tedy chceme přečíst čistě RAX registr, stačí využít těchto posunů a prakticky to lze vidět ve @ptrace-concept[Výpisu] a ve @breakpoint-creation-example[Výpisu]. Kernel zapisuje do USER regionu při vyhození procesu z CPU a načítá z něj, když dává proces zpátky na CPU. #footnote[Tato informace je můj předpoklad, nedokázal jsem najít žádný text, který by tohle potvrzoval a jediný způsob pro potvrzení by bylo hrabat se ve zdrojovém kódu kernelu.]

Musíme tedy uložit původní slovo, nahradit ho za `0xCC` byte, počkat než program vyhodí SIGTRAP, vrátit zpátky původní slovo a dekrementovat RIP. V literatuře a na internetu se tomuhle postupu říká softwarový breakpoint. @breakpoint-creation-example ukazuje tvorbu tohoto breakpointu v jazyce Rust.

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

Tento postup jsem zvolil i v práci, primárně díky jeho jednoduchosti, ale taky, protože jsem úplně nevěděl o druhém způsobu. A plně upřímně, když se na celou sekci o něm dívám teď, asi bych neměl dost nervů na to ho rozjet.

==== Ladící registry
x86-64 nabízí několik ladících registrů, označené DR0 až DR7. Je možné do nich zapisovat pouze z CPL 0.
#footnote[CPL, zkratka pro Current Privilege Level je současná ochranná úroveň (privilege level, někde se využívá analogie s ochrannými prstenci, protection rings) běžícího úseku kódu. Instrukce vykonané v CPL 0 vykonává zpravidla pouze kernel, instrukce v CPL 3 jsou vykonané všemi programy v userspace (mimo kernel). @intel-volume3[kap. 5.5]]

Struktura celého USER regionu, zmíněného v předchozí kapitole, se nachází ve struktuře `user`, definované v `<sys/user.h>`. #footnote[Doporučuji se do tohoto souboru podívat jenom kvůli jeho úvodnímu blokovému komentáři o GDB.] Úplně poslední částí této struktury je pole o velikosti 8 64bitových čísel pojmenované `u_debugreg` a právě tohle obsahuje debug registry, od DR0 po DR7. Pokud je tedy proces zastaven, můžeme nastavit zde jakoukoliv vyžadovanou hodnotu a kernel ji poté načte do CPU když CPL je 0.

Teď když víme, jak načíst hodnotu do ladící registru, jaké hodnoty tam vlastně chceme načíst? Pokud se vrátíme ke svaté bibli x86-64 (odkaz na kapitolu v citaci), zjistíme, že registry DR0 až DR3 drží nějakou adresu v paměti, DR6 obsahuje informace o poslední vygenerované \#BP a DR7 obsahuje nastavení ladění. Zbytek je registrů rezervovaný (nejspíše už navždy). @intel-volume3[kap. 18.2] Jak nastavit DR7, aby došlo k \#BP na spuštění instrukce ze vstupní adresy je už mimo rozsah tohoto textu, ale ve zkratce, jde o aktivování breakpointu a nastavení, aby vyvolal \#BP na spuštění instrukce. #footnote[V hardwarových breakpointech lze program přerušit i na čtení a zápis ze zadané adresy, *extrémně* užitečné pro ladění.] Rust má slibně vypadající balíček `x86` s modulem `debugregs`, #footnote[https://docs.rs/x86/latest/x86/debugregs/index.html] který umí automatizovat většinu práce složitého nastavování bitů.


=== Čtení mapovaných regionů paměti <memory-maps>
Aby vytvoření breakpointu nebylo až moc jednoduché, musíme ještě získat správnou adresu. Vstupní adresa je relativní ke startu ELF souboru, ale nikoliv k adrese v paměti. Při `execve` kernel načte celý program do paměti a ačkoliv program může přímo pracovat s relativními adresami, pokud chceme zapsat do paměti sledovaného, musíme získat _reálnou virtuální_ adresu.

Kernel drží v `procfs` soubor `maps` pro každé PID, který obsahuje mapované oblasti paměti pro proces. Jeho formát je popsaný v citované manuálové stránce, nicméně ve zkratce obsahuje rozsah virtuální adresy a její posun od relativní. Když chceme převést relativní adresu na virtuální, stačí vzít posun, který bereme jako start daného záznamu a přičíst k němu rozsah, který po součtu bereme jako konec oblasti záznamu. Pokud je naše adresa mezi začátkem a koncem záznamu, stačí pouze přičíst naši adresu ke adrese startu rozsahu. Pokud naše adresa není mezi koncem a začátkem, pokračujeme k dalšímu záznamu. @proc-pid-mem

V práci jsem tedy musel načíst vstupní adresu ELF souboru, poté ji převést na virtuální adresu, nastavit na ni instrukci `0xCC` a po její aktivaci nahradit za původní byte. Výsledkem tohoto je, že BouboTrace umí přeskočit počáteční kroky spouštění programu.

== Sledované systémové volání
BouboTrace umí zpracovat minimálně následující systémové volání: `openat`, `read`, `write`, `close`, `socket`, `bind`, `listen`, `accept` a `exit_group`. U všech ostatních volání je uloženo jejich číslo, registry s parametry a návratová hodnota.


== Serializace dat
Implementace serializace dat jsem udělal přes balíček `serde`, který nabízí serializaci do různých formátů. V tomhle případě jsem zvolil JSON.

Aby struktura mohla být serializována, používá se zpravidla `serde::Serialize` makra. V ideálním případu stačí tohle makro aplikovat na strukturu a vše jde najednou lehce serializovat, bohužel, reálný svět takový není, protože používat makra můžeme pouze na vlastní struktury. BouboTrace používá na mnoha místech struktury z jiných knihoven, třeba pro `openat` vlajky. V práci jsem pro tyto typy implementoval tzv. newtype návrhový vzor, kdy je typ z cizí knihovny obalen v lokálním typu a pro tento typ jsem napsal ručně `Serialize` implementaci. V práci je tak obalen každý typ, který to vyžadoval.

Pro testovací účely jsem napsal jednoduchý iterátor, který načte všechny data do vektoru a serializuje. Výsledkem byl JSON podobný tomu ve @original-json[Výpisu], který nicméně dle mého názoru nebyl moc dobře čitelný.

#figure(
  ```json
  [
    {
      "Ok": {
        "close": {
          "fd": 3
        }
      },
    },
    {
      "Ok": {
        "exit_group": {
          "status": 0
        }
      }
    },
    {
      "Error": "tracee process is not running and exited with status code 0"
    }
  ]
  ```,
  caption: [Původní serializovaný JSON],
) <original-json>

Problémem je výchozí serializace `Result` struktury, která dává poměrně zbytečné `Error` a `Ok` klíče. Mnohem větší smysl za mě dávalo mít jako hlavní klíč jméno systémového volání a pak nějaké pojmenování pro chybu. Tím jsem se dostal k výsledné struktuře, která je ve @final-json[Výpisu].

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
  caption: [Finální podoba serializovaného JSONu],
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

= Evaluace implementace
V této kapitole se podíváme na funkčnost výsledného řešení. Jedním z cílů BouboTrace bylo zaručit, aby trasované programy jely tak, jako by nebyly trasované. K tomu je klíčové, aby trasování nebylo nějak ovlivněno a aby bylo rychlé.

== Bezvadnost <correctness>
Sledovatel by neplnil jeho práci moc dobře, pokud by omezil funkci sledovaného. Je tedy klíčové, aby BouboTrace zasahoval do funkčnosti sledovaného co nejméně. V rámci tohoto testování jsem postupoval jednoduše, prostě jsem spustil nějaký větší program a sledoval, jak se chová.

První problém jsem objevil v Chromium. Z nějakého důvodu Chromium na mém systému se vždy ukončí se signálem SIGSEGV. V té době jsem neměl zprovozněné předávání signálů (rozebrané v @ptrace-signals[Kapitole] a implementované v @tracee-struct[Kapitole]). Co se tedy na konci stalo bylo, že sledovaný (zde Chromium) neustále dokola spouštěl instrukci, která doručila SIGSEGV. #footnote[CPU vrátí čítač instrukcí nad adresu před instrukcí, která vyvolala chybu (v tomhle případě page fault, kterou pak kernel doručí jako SIGSEGV). @intel-volume3[kap. 6.5]] Tento signál byl doručen sledovateli, ale nikdy nedorazil sledovanému. Sledovatel jenom pokračoval s exekucí sledovaného a tak pořád dokola. Řešením bylo uložit všechny získané signály a pak je později doručit. V případě SIGSEGV, pokud daný proces nemá k němu signal handler, tak obdrží SIGKILL a je ukončen.

Zkoušel jsem pak i různé další programy, jako Firefox, Dolphin, Darktable, GIMP, Krita, VLC a jiné. U žádného z nich jsem nezaznamenal nějaký problém během toho, co byl trasován. Je ale dobré zmínit, že BouboTrace nepodporuje sledování více vláken naráz, sleduje pouze jenom hlavní (viz @support-threads).

== Rychlost
// TODO otestovat rychlost
Jedním z důvodů, proč jsem zvolil jazyk Rust, byla právě rychlost.

= Možnosti rozšíření
Bohužel, čas na bakalářskou práci je limitovaný, a to znamená, že ne na každý nápad je čas. Proto se v této kapitole podíváme na prvky práce, které jsem nestihl nebo nezvládl dokončit nebo začít.

== Sledování více systémových volání
Systémových volání v Linuxu je _extrémně *hodně*_ a realisticky jsem je nemohl všechny implementovat pro tuhle práci. Nicméně pro úplnou funkčnost by bylo nezbytné implementovat minimálně ty, které provádí nějakou manipulaci s vnějším světem (není úplně nutné sledovat třeba `poll`, ale je důležité sledovat např. `creat`, `mmap`, `mprotect`, `ioctl` a další). V rámci práce jsem nicméně implementoval všechny nutné základy pro jednoduché přidávání dalších volání (zejména kopírování z paměti sledovaného, ale i celá `ptrace` infrastruktura).

== Podpora vláken <support-threads>
V současném stavu BouboTrace sleduje jenom jedno vlákno procesu. Je známo, že se zavolal `clone`, `fork` nebo `execve`, ale tato informace není nijak využita a druhé vlákno není sledované. Vzhledem k tomu, že BouboTrace má být ke sledování velkých programů, které *používají* vlákna, je tato funkcionalita nesmírně užitečná pro reálné využití. `ptrace` obsahuje možnosti pro automatické sledování dětí sledovaného, jde jenom o to v nich provést přeskočení do `main` funkce, pokud třeba, a sledovat veškerou akci v nich (ideálně paralelně) společně s hlavním procesem. Myšlenkově nejde o moc složité téma, implementačně ano.

== Rozbalení zásobníku
Představme si situaci, kdy se zpětně díváme na seznam volání nějakého programu a vidíme, že udělal `write`, který vypsal nějaký text do konzole. Bylo by extrémně užitečné vědět, který řádek našeho kódu tohle volání udělal. ELF soubor může obsahovat ladící symboly, které umožňují vytrasovat danou instrukci k řádku kódu. Problém je, že je k tomu potřeba ve většině případů rozbalit zásobník.

Rozbalením zásobníku se rozumí, že po něm putujeme nahoru po stopách zavolaných funkcí. Každé volání funkce vytváří na zásobníku nový rámec začínající adresou předchozího volání. Pokud tedy v našem kódu zavoláme `printf` a v něm se zavolá `write`, stane se tak v rámci `printf` a ne v našem rámci, tudíž současná adresa není uvnitř našeho kódu a nemůžeme přečíst část, kde byl zavolaný `printf`. Řešení je zde putovat po zásobníku, než dorazíme do bodu, kdy se `printf` zavolal. @intel-volume2[kap. 3.3]

V praxi tohle udělat správně je šíleně komplexní záležitost. Existuje na to několik řešení a balíčků, nicméně jsem se nedostal k žádnému z nich. Pokud bych někdy tuto funkcionalitu implementoval v potencionálním rozšíření BouboTrace, jednalo by se o takovou _hlavní věc, která jinde není_, GDB sice umožňuje zastavovat na systémových volání, ale extrémně blbě se to filtruje.

== Testování
Testování je v základní fázi v BouboTrace udělané za pomocí snapshotů za pomocí balíčku `insta`. #footnote[https://docs.rs/insta/latest/insta/]. Proces testování funguje na `Debug` výpisu vektoru se systémovými volání a chybami, kdy se jeho obsah porovnává vždy s předchozím testem a zjišťují se rozdíly mezi nimi. Ty se pak můžou schválit jako platné, nebo vrátit zpátky jako chyba. Tento postup je výborný jak pro programy postupně přidávající funkcionalitu, tak i pro programy testující, co se změnilo po nějakých úpravách.

Snapshot testing v BouboTrace funguje jak má a celý proces je (včetně překladu testovacích souborů) automatizovaný. První problém je, že se porovnává `Debug` výpis, což není úplně ideální a mnohem větší smysl by dávalo porovnávat serializovaný JSON. Druhý problém je, že velice hodně parametrů systémových volání se mění s každým během programu. `openat` vrátí jiný file descriptor. `socket` dá jiné číslo socketu. `mprotect` pracuje s jinou adresou v paměti. A tak dále. Řešením zde by bylo přidat do testů ignorování pro určité hodnoty. `insta` tuto funkcionalitu má, ale použít ji korektně pro každý test tak, aby se stále testovalo všechno nezbytné, je komplikované.

== Držení informací o současném stavu
V situaci, kdy program běží by se nebylo špatné zeptat BouboTrace, co má aktivně otevřené a co používá. V praxi na tohle existují už jiné nástroje, které tuto práci zvládají dobře (např. `lsof` a `htop`), nicméně nebylo by špatné mít všechno na jednom místě a i s případnou historií. Nejedná se rozhodně o tak podstatně chybějící funkcionalitu, jako rozbalování zásobníku, ale nazval bych ji jako _nice-to-have_.


= Závěr
V rámci této práce jsem popsal důvody, proč současné řešení nestačí na sledování komplexních programů a zavítal do této problematiky snahou o implementaci takového nástroje. Implementovaný nástroj umí snímat systémové volání, serializovat je do souboru a skočit v ELF souboru až do relevantní části. Je v něm i kompletní CLI s možností nastavit některé atributy chování programu. Nástroj je postaven tak, aby byl velice rozšířitelný o všechny původně zamýšlené funkcionality.

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

Po spuštění s `--help` vypíše program uživateli nápovědu, nicméně pokud chceme nastavit pracující složku na `work_dir`, vypsat každou hlášku, uložit výsledek do souboru `out.json` a spustit program `a.out`, zadáme následující příkaz: `cargo run -r -- -w work_dir/ a.out -vvv -o out.json`. BouboTrace kontroluje všechny špatně zadané cesty a vypíše v tomhle případě chybovou hlášku.

