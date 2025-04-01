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

// Uncomment the parameter in paranthesis to disable first line indent and increase paragraph spacing. Guidelines don't mention any *correct* way, but latex template uses first line indent.
#show: temp.template.with(/* firstLineIndent: false */ )

#set text(
  // SET YOUR LANGUAGE HERE CORRECTLY
  // use "cs" or "en", "sk" is not fully supported by typst
  // when you're using Czech, all conjunctions get an unbreabakle space appended by the template, to prevent them from displaying as last characters on the line
  lang: "cs",
  // Template uses Calibri by default (because it's very available and we optimized font sizes for it), if you want to overwrite that (guideline allows for more fonts, see links in template.typ), do it below
  // I peronally recommend Carlito as sans-serif and Tex Gyre Pangella (based on Palatino)
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
// TODO fill all of these in
#temp.abstracts(
  [není to zadarmo],
  [it's not free],
  czechKeywords,
  englishKeywords,
  // If writing in Slovak, you can optionally provide keywords and abstracts in Slovak
  // slovakAbstract: [nie je to zadarmo],
  // slovakKeywords: ("kľúčové slovo 1", "kľúčové slovo 2"),
  // You can also add a quote, if you feel like it
  // and get insanely creative with it
  quote: quote(
    [
      #text(lang: "he")[
        ויאמר משה אל יהוה בי אדני לא איש דברים אנכי גם מתמול גם משלשם גם מאז דברך אל עבדך כי כבד פה וכבד לשון אנכי׃
      ]
    ],
    attribution: [
      _The Bible_, Exodus 4:10 #footnote([But Moses replied to the LORD, "Please, Lord, I have never been eloquent--either in the past or recently or since You have been speaking to Your servant--because I am slow and hesitant in speech." @bible]) @hebrew-bible
    ],
    block: true,
  ),
  acknowledgment: [Thank you],
  // In case you need to set custom abstract spacing
  // abstractSpacing: 2.5cm,
)


// Page numbering starts with outline
#set page(numbering: "1")


// Uncomment this if you don't want chapter title in headers
// headerHeadingPage sets if a header should be shown on a page starting with header
#show: temp.headerChapters.with(headerHeadingPage: false)
#temp.listChapters


// List of symbols and abbreviations, automatically alphabetically sorted
// you can use packages libe abbr or acrostatic for this, if you want more automatic handling
// TODO don't forget the symbols
#temp.listSymbols((
  ("GDB", "GNU Debugger"),
  ("CPU", "Central Processing Unit"),
  ("OS", "Operační systém"),
  ("PID", [Process #text(weight: "bold")[id]entification]),
  ("FFI", "Foreign Function Interface"),
))

// List of Figures
#temp.listImages


// List of Tables
#temp.listTables


// Start heading numbering
#set heading(numbering: "1.1.1")

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
Při psaní programů, ať už v jakémkoliv paradigmatu nebo jazyce, každý programátor eventuálně řeší nějaký logický problém v programu. Tyhle problémy šahají od tlačítka, které z nějakého důvodu nic nedělá, až po finančně několika miliardové chyby. Pro zabránění, pochopení a prevenci těchto problémů byla vytvořena řada nástrojů a postupů. I přes jejich nepřeberné množství je stále možné najít nějakou nevyplněnou díru, postup nebo nástroj, který ještě nebyl vytvořen a správně vyzkoušen.

// TODO tento odstavec je moc krátký tbh
Sledování a pochopení fungování velkých programů vyžaduje velké úsilí a neexistují pro to žádné specificky určené nástroje, o kterých bych věděl. #footnote[Existující alternativy jsou více rozebrané v @existing-solutions[Kapitole].] Proces pochopení složitého programu pak trvá velice dlouho.

Cílem práce je napsat nástroj a pochopit principy, jež by ulehčily analýzu programů, které prostě a jednoduše dělají až moc věcí. Kvůli potencionální složitosti takového řešení se v této práci podíváme pouze na základní kameny takového nástroje, nicméně jsem otevřen tento nástroj do budoucna dále rozvíjet.

// FIXME to "my se podíváme" sem asi nepatří xddd
V úvodních kapitolách se podíváme na principy zejména z operačních systémů, od popisu systémových volání až po `ptrace`. Následně si ukážeme existující nástroje a jejich dobré a chybějící vlastnosti relevantní pro větší programy. Po těchto základních věcech se dostaneme konečně k samotné implementaci a její evaluaci a na závěr si všechno shrneme.

// FIXME tyhle sekce by neměly být v úvodu imo
// Poměrně běžným postupem analýzy programu je krokování. Problémem u krokování je, že nikdy nenakreslí celý obrázek chování programu. Umožní nám pouze postupně procházet a analyzovat části programu, ze kterých postupně můžeme tento obrázek nakreslit. Tento postup i relativně dobře funguje, dokud je program dostatečně malý. Jakmile začne program růst na velikosti a komplexnosti, pochopit funkci každého šroubu a matice pracujícího v zákulisí nedává pro jednoho ubohého programátora smysl.
//
// Další možností je program spustit v nějakém nástroji na měření výkonu programu. Tím si samozřejmě dokážeme o programu nakreslit obecnější obrázek, než nám poskytne krokování, nicméně ná

// Krokování a diagnostikování chování programů prochází programátora každodenním životem. Některé problémy jsou komplikovanější než jiné a je potřeba využít nástrojů určených k této diagnostice. Co se samotného krokování týče, k dispozici je hromada nástrojů ulehčující tento proces, nicméně pokud se podíváme na analýzu chování programu bez krokování, situace je mnohem složitější. Nástroje, které jsou pro tohle k dispozici jsou většinou poměrně dost limitované nebo některé věci neumožňují.

// TODO tohle jsem vzal z práce Dana Trnky, stojí za to se zauvažovat nad tím, co vlastně chceme sledovat
= Sledovaná data

// FIXME název této kapitoly se mi moc nelíbí, možná by to mohly být přímo ty systémové volání
= Základní principy a pojmy
Pro pochopení implementace a evaluace je potřeba se obeznámit se některými základnímí principy využitých v práci.


== Systémové volání
Moderní operační systémy izolují procesy v nich běžící od přímého přístupu k hardware. K tomu, aby proces mohl získat nějaké data z hardware, požádá o ně operační systém přes systémové volání. Způsob spouštění a předávání argumentů systémových volání se liší podle OS a podle architektury CPU #footnote[V případě x86-64 se k tomu dá použít instrukce `SYSCALL`. Parametry jsou předávány přes CPU registry. @intel-volume3[kap. 5.8.8] @syscall], nicméně ve valné většině případů existují knihovní procedury pro jazyk C (pro Linux se tato knihovna jmenuje `libc`) umožňující volat systémové volání. @tanenbaum-operating[kap. 1.6] Ve @write-example[Výpise] lze vidět, jak můžeme využít jazyk C k použití systémového volání `write` k výpisu na standardní výstup.

#figure(
  raw(read("source_codes/write_example.c"), block: true, lang: "C"),
  caption: [Využití systémového volání `write` v C],
) <write-example>

Systémové volání zpravidla obsluhují I/O, nicméně může jít i o více komplikované věci, třeba uzamykání určitých oblastí paměti. #footnote[Viz #link("https://man7.org/linux/man-pages/man2/mprotect.2.html")[manuálová stránka pro `mprotect`].] Pro účely této práce jsou taky skvělý způsob jak zjistit, co program reálně dělá.

Parametry knihovní procedury se ne vždy shodují s parametry systémového volání. #footnote[`clone` systémové volání má jiné parametry, než procedura; tyhle parametry se liší i mezi architekturami. @clone] Stejně tak název procedury není nutně systémové volání, které daná procedura zavolá. #footnote[Zde tomu je třeba u systémového volání `fork`, `libc` procedura volá místo něj `clone`. @fork] @fork @clone


=== Systémové volání `ptrace`
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

Proces, který používá `ptrace` na jiný proces (tzn. že zadává jeho PID do `pid` parametru) se nazývá "tracer" (sledovatel) a proces, který je sledován Sledovatelem se nazývá "tracee" (sledovaný). Pojmy "sledovatel" a "sledující" budou nadále používány v práci. Aby sledovatel mohl monitorovat sledovaný proces, musí sledovaný nejprve zavolat `ptrace(PTRACE_TRACEME)` a musí být potomkem sledovatele. #footnote[Tohle není nutně vždy pravda. `ptrace` má nastavitelné přístupové módy a můžou být jak více volné, tak i více limitující až kompletně zakázaný. @ptrace]

==== Příklad incializace `ptrace`
#figure(
  raw(read("source_codes/ptrace_example.c"), block: true, lang: "C"),
  caption: [Ukázka připojení k procesu přes `ptrace`],
) <ptrace-example>

Ve @ptrace-example[Výpisu] lze vidět základní nastavení používání `ptrace`. Nejprve je zavolána procedura `fork`, která zkopíruje vše o současném procesu do nového procesu, který je potomek současného procesu. Novému procesu (dítěti) dá návratovou hodnotu 0, rodiči vrátí PID dítěte. @fork Dítě potom zavolá `ptrace` s `PTRACE_TRACEME` operaci, díky které (1) dovolí rodiči dělat na daném procesu `ptrace` operace (2) zastaví sám sebe. Rodič tedy čeká (za pomocí systémového volání `waitpid`), než se dítě zastaví a jakmile je zastaveno, tak pokračuje #footnote[V korektní `ptrace` terminologii je sledovaný restartován.] s jeho spouštěním.


==== Práce se signály
Pokud sledovaný obdrží nějaký signál, tento signál mu nikdy není doručen. Místo toho je tento signál doručen přes systémové volání `waitpid` sledovateli. Je sledovatelova povinnost poté tento signál předat dál (např. přes parametr `data` v operaci `PTRACE_CONT`) anebo ho nějak jinak zpracovat. Výjimku v tomto chování tvoří `SIGKILL`. @ptrace



=== Systémové volání `process_vm_readv` a `process_vm_writev`
Abychom mohli přečíst argumenty, které byly předány do systémového volání a ukazují na nějaké data v paměti sledovaného, musíme zkopírovat paměť ze sledovaného do sledovatele. Jsou celkem tři způsoby, jak tohoto dosáhnout: @trnka-thesis[kap. 4.2]

+ `ptrace(PTRACE_PEEKTEXT)` a `ptrace(PTRACE_PEEKUSER)` #footnote[`PTRACE_PEEKUSER` vrací data z `USER` části paměti, obsahující např. registry a informace o procesu.] -- Výhodou těchto volání je, že jsou velice jednoduché na použití. Stačí zadat adresu, ze které chceme číst a přečtená hodnota je vrácena jako návratová hodnota. Nevýhodou je, že lze číst pouze po jenom hardwarovém slově, tedy pro každé hardwarové slovo je potřeba udělat jedno volání. Ve výsledku je to poměrně efektivní řešení pro data o velikosti jednoho slova (např. registry), ale velice neefektivní pro větší data (např. řetězce).
+ Soubor `/proc/pid/mem` -- PID nahrazujeme za PID procesu; jedná se o klasický soubor, který obsahuje paměť daného procesu. Pracuje se s ním, jako s klasickým souborem, tudíž ho nejdříve otevřeme přes `open()` a poté přes `lseek()` #footnote[Systémové volání `open` a `lseek` lze nahradit za funkce v C standardu (`fopen` a `fseek`).] se přesuneme na adresu, kterou chceme číst. Nakonec použijeme `read` pro čtení adresy. @proc-pid-mem Jak si můžete všimnout, nevýhoda tohoto postupu je, že zahrnuje poměrně dost kroků a systémových volání pro čtení jedné adresy, nicméně oproti první metodě pro větší množství dat vyžaduje méně systémových volání.
+ `process_vm_readv`/`process_vm_writev` -- Systémové volání, které umožňují kopírovat přímo paměť mězi dvěma procesy. Výhodou je, že volání kopíruje data přímo mezi procesy (data nejdou přes kernel). Umožňují taky poměrně komplexní způsoby kopírování. @process_vm Nevýhodou je komplexnost použití, nicméně primárně díky rychlosti těchto systémových volání byly vybrány jako způsob pro kopírování paměti ze sledovatele do sledovaného.

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
      void   *iov_base;  /* Adresa, ze/do chceme číst/zapisovat */
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

Pokud se během kopírování naplní jedno `iov_base` pole v `local_iov`, přejde se na další v pořadí i pokud jsme pořád ve stejném poli v `remote_iov`. Jinými slovy, jedno pole v `remote_iov` může naplnit dvě pole v `local_iov` a opačně. V návratové hodnotě je celkový počet zkopírovaných bytů. Pokud `remote_iov` přesahuje do neplatné paměti, celé kopírování okamžitě skončí a systémové volání vrátí počet zkopírovaných bytů do té doby. Tohle použití je velice relevantní pro implementací v této práci a je více rozebráno v // TODO doplnit kapitolu

= Programovací jazyk Rust
Programovací jazyk je tzv. "memory-safe" nízkoúrovňový systémový jazyk, který klade důraz na výkon, souběh a typovou bezpečnost. Nepoužívá ani garbage collector; místo toho používá "borrow checker," který kontroluje platnost referencí a dobu jejich života během překladu. Všechny proměnné jsou také ve výchozím stavu "non-mutable," tzn. že nelze přepsat jejich obsah. Půjčuje si hodně vzorů z funkcionálních jazyků, nicméně objevuje se v něm i pár konceptů z OOP. Protože v nízkoúrovňovém prostředí nemůže být úplně všechno bezpečné, umožňuje jazyk Rust některé pravidla obejít v `unsafe` blocích. @rust-astrophysics[kap. 2].

Jazyk Rust používá systém Cargo pro správu testů, parametrů překladu, verze programu a mnoho dalšího. Jední z konceptů v Cargo je "crate," jedná se o nějaký zdrojový kód, který je dostupný lokálně nebo z internetu a jakmile je přidaný do současného projektu, je možné importovat jeho veřejné členy v současném projektu. @rust-book[kap. 7]

Rust rovněž umožňuje propojení s jinými nízkoúrovňovými programovacími jazyky za pomocí FFI. Je tedy možné poměrně jednoduše volat funkce z C nebo C++. Všechny funkce definované přes FFI jsou ve výchozím stavu unsafe, nicméně lze kolem nich udělat bezpečné obaly, jak je tomu ve @ffi-example[Výpise]. @rustonomicon[kap. 11]

#figure(
  raw(read("source_codes/ffi/src/lib.rs"), block: true, lang: "rust"),
  caption: [Ukázka použití knihovny `snappy` přes FFI v jazyce Rust. @rustonomicon[kap. 11]],
) <ffi-example>

Jazyk Rust byl zvolen pro tuhle práci zejména díky, dle mého názoru, skvělému syntaxu. Rychlost a bezpečnost už jsou jenom takové třešničky na dortu.


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

Pro (zatím) všechny přímé systémové volání v práci byl využit balíček `nix`. Některé potencionálně užitečné definice v něm někdy nejsou nadefinované, #footnote[Příkladem zde je operace `PTRACE_GET_SYSCALL_INFO`. Je dostupná v `libc`, ale v `nix` zatím nebyla implementována. Je o tom již dlouhodobě aktivní PR: https://github.com/nix-rust/nix/pull/2006.] nicméně dá se bez nich většinou obejít a případně zavolat přímo přes `libc`.


= Existující alternativy <existing-solutions>
V této kapitole se podíváme na existující alternativy k řešení. U každé z nich je uveden krátký popis včetně toho, proč je její použití vhodné či nevhodné.

= Implementace <implementation>


#bibliography(
  "bibliography.yml",
  // this style is required by the styleguide
  style: templFolder + "iso690-numeric-brackets-cs.csl",
)

// Start appendix
#show: temp.appendix

= First thing
#lorem(50)

= Second thing
#lorem(50)
