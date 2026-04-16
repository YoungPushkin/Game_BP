# Integrácia máp z LDtk a Tiled do projektu

Tento dokument slúži ako doplnkové technické vysvetlenie k praktickej časti projektu `Prežiť po`. Jeho cieľom je zrozumiteľne ukázať, ako prebieha import máp z editorov `LDtk` a `Tiled`, aké skripty sa pri tom používajú a prečo bolo potrebné doplniť vlastnú post-import logiku v prostredí `Godot`.

Popis je rozdelený na dve časti:

1. integrácia úrovne vytvorenej v `LDtk`,
2. integrácia úrovne vytvorenej v `Tiled`.

## 1. LDtk

### 1.1 Celkový priebeh importu

Pri editore `LDtk` sa úroveň najskôr vytvára ako dátová štruktúra pozostávajúca z vrstiev, entít, polí a pomocných grid vrstiev. Samotný súbor `level2.ldtk` ešte nepredstavuje hotovú hernú scénu, ale iba zdroj údajov, ktoré je potrebné po importe ďalej spracovať.

Základný priebeh je znázornený na nasledujúcej schéme:

![LDtk import workflow](shema%20git/ldtk1.png)

Na začiatku vstupuje do procesu zdrojový súbor `level2.ldtk`. Ten sa importuje pomocou konfigurácie `level2.ldtk.import`, pričom súčasťou nastavenia sú aj post-import kroky, ktoré zabezpečujú ďalšie spracovanie úrovne. Importér `Amano LDtk Importer` vytvorí základnú scénu, ale na to, aby sa z nej stala plnohodnotná herná úroveň, je ešte potrebné spustiť projektové skripty `level2_entities.gd` a `level2_level.gd`.

Práve tieto skripty zabezpečujú, že importovaná mapa nie je iba vizuálnou reprezentáciou dát, ale reálne funguje v projekte ako testovateľná úroveň.

### 1.2 Premena entít na scény projektu

Jedným z najdôležitejších krokov integrácie je spracovanie entít z `LDtk`. V editore sú entity uložené ako dátové záznamy, ale projekt v `Godot` potrebuje pracovať s konkrétnymi scénami, ktoré majú vlastné skripty, správanie a internú logiku.

Tento princíp zobrazuje nasledujúca schéma:

![LDtk entity to scene mapping](shema%20git/ldtk2.png)

Skript `level2_entities.gd` prijíma entity vrstvu po importe cez `post_import(entity_layer)`. Následne podľa identifikátora entity vyhľadá v mape `entity_scene_path`, ktorá scéna projektu zodpovedá danej entite. Pomocou funkcie `_make_instance(identifier)` sa vytvorí konkrétny inštančný objekt a vloží sa do úrovne v `Godot`.

Tento krok je nevyhnutný preto, lebo bez neho by sa do hry preniesli iba samotné dáta z editora. Hra by síce vedela, že sa na určitom mieste nachádza terminál, dvere alebo modul, ale nevznikol by z toho skutočný objekt so správaním. Až vytvorenie správnej projektovej scény zabezpečí, že objekt bude reagovať na hráča a zapojí sa do hernej logiky.

### 1.3 Rozdelenie údajov na vlastnosti a metadata

Po vytvorení inštancie scény je potrebné správne preniesť údaje z `LDtk` do konkrétnych objektov v hre. Túto časť ilustruje nasledujúca schéma:

![LDtk fields and metadata](shema%20git/ldtk3.png)

V `level2_entities.gd` sa po vytvorení objektu spracujú polia entity. Časť hodnôt sa zapisuje priamo ako vlastnosti objektu cez `instance.set()`, zatiaľ čo iné sa ukladajú ako metadata pomocou `instance.set_meta()`.

Toto rozdelenie má praktický význam:

1. Priame vlastnosti sa používajú tam, kde ich herná logika potrebuje okamžite a opakovane, napríklad `required_active_moduletables`, `door_id` alebo `module_type`.
2. Metadata sa používajú pri pomocných alebo prepájacích údajoch, napríklad `target_door_id` alebo `entity_id`, ktoré sú dôležité pri neskoršom prepájaní objektov, ale nie je potrebné ich mať ako bežné exportované premenné v každej scéne.

Takýto prístup zjednodušuje architektúru projektu. Scény zostávajú prehľadnejšie a zároveň sa zachováva dostatok údajov na budovanie väzieb medzi objektmi po importe.

### 1.4 Prepojenie terminálov a dverí

Po importe entít je ešte potrebné prepojiť objekty, ktoré v editore súvisia logicky, ale po importe medzi nimi neexistuje automatická referencia v `Godot`.

Túto časť vysvetľuje nasledujúca schéma:

![LDtk terminal and door binding](shema%20git/ldtk4.png)

Skript `level2_level.gd` pri post-import spracovaní vyhľadá objekty dverí v úrovni a vytvorí internú mapu dostupných dverí. Terminál má v metadata uložený údaj `target_door_id`, na základe ktorého sa určí, ktoré dvere má ovládať. Následne sa terminálu priradí príslušná cesta `door_path`.

Vo chvíli, keď sa terminál aktivuje, skript `terminal.gd` pomocou `_find_door()` nájde konkrétny objekt dverí a vyvolá jeho správanie, napríklad `open_from_terminal()` v `door.gd`.

Bez tejto post-import väzby by terminály a dvere síce existovali v jednej scéne, ale neboli by funkčne prepojené. Hráč by tak mohol aktivovať terminál bez toho, aby sa v úrovni naozaj otvorili zodpovedajúce dvere.

### 1.5 Prestavba kolízií sveta

Osobitnú úlohu pri integrácii `LDtk` zohráva kolízna vrstva. V editore je kolízia zapísaná ako `IntGrid` vrstva `Kollizia`, ktorú projekt nemohol použiť v pôvodnej podobe priamo.

Postup spracovania tejto vrstvy ukazuje nasledujúca schéma:

![LDtk world collision rebuild](shema%20git/ldtk5.png)

V `level2_level.gd` sa po importe najskôr podľa potreby deaktivujú vstavané kolízie dlaždicových vrstiev. Následne sa vyhľadá surová vrstva `Kollizia` a z jej údajov sa vytvorí jednotná svetová kolízna štruktúra. Funkcie ako `_rebuild_world_collision()`, `_find_raw_layer()`, `_add_world_collision_shapes()` a `_create_world_shape()` generujú finálny uzol `generated_world_collision`.

Tento uzol je dôležitý pre dve časti projektu:

1. pre pohyb hráča,
2. pre výpočet hraníc kamery v `player_camera.gd`.

Kamera cez `_find_world_collision(root)`, `_get_collision_rect(root)` a `_set_limits(bounds)` určuje hranice úrovne práve podľa tejto výslednej collision štruktúry. To znamená, že hráč aj kamera vychádzajú z rovnakého základu, čo zabezpečuje stabilnejšie a predvídateľnejšie správanie úrovne po importe.

### 1.6 Zhrnutie integrácie LDtk

Integrácia `LDtk` v projekte preto neznamenala iba načítanie mapy. Zahŕňala viacero navzájom prepojených krokov:

1. import dát z `level2.ldtk`,
2. prevod entít na skutočné scény projektu,
3. rozdelenie údajov na vlastnosti a metadata,
4. manuálne prepojenie terminálov a dverí,
5. prestavbu svetových kolízií do spoločného uzla,
6. napojenie výslednej štruktúry na pohyb hráča a limity kamery.

Práve preto sa `LDtk` ukázal ako veľmi silný nástroj na prípravu logickej a dátovej štruktúry úrovne, no zároveň ako editor s najvyššou integračnou náročnosťou.

## 2. Tiled

### 2.1 Celkový priebeh importu

Pri editore `Tiled` bol postup odlišný. Import neprebiehal cez dátovo orientovaný model entít ako pri `LDtk`, ale cez importér `YATI`, ktorý vytvoril z mapy hotovejšiu scénu pre `Godot`.

Základnú logiku importu zobrazuje nasledujúca schéma:

![Tiled import workflow](shema%20git/tiled1.png)

Mapa vytvorená v `Tiled` sa importuje cez `YATI importer`, ktorý vytvorí scénu so zachovanými hlavnými vrstvami, napríklad `World`, `World_Collision`, `World_decor`, `ladder` a `entities`. Výsledkom je úroveň v `Godot`, ktorá už má pripravenú základnú štruktúru. Súčasťou importu je aj uzol `generated_world_collision`, čo uľahčuje ďalšie spracovanie mapy v projekte.

Na rozdiel od `LDtk` je teda cesta k hotovej scéne kratšia. Zároveň však dôležitá časť údajov prichádza vo forme metadata, takže na strane projektu je potrebné upraviť skripty tak, aby tieto hodnoty správne čítali a používali.

### 2.2 Prispôsobenie skriptov po importe

Keďže import z `Tiled` neprenášal všetky logické väzby v podobe, ktorú projekt vedel okamžite použiť, bolo potrebné prispôsobiť niektoré herné skripty.

Túto časť zobrazuje nasledujúca schéma:

![Tiled metadata adaptation](shema%20git/tiled2.png)

Po importe cez `YATI` zostali viaceré údaje objektov dostupné najmä cez metadata values. To znamená, že skripty `moduletable.gd`, `terminal.gd` a `level_navigation.gd` museli byť doplnené tak, aby tieto hodnoty správne načítali a interpretovali.

Tento krok bol dôležitý najmä pri objektoch, ktoré neplnili iba vizuálnu funkciu, ale priamo ovplyvňovali herný postup:

1. moduly a miesta ich aktivácie,
2. terminály,
3. dvere,
4. navigačné väzby v úrovni.

Ak by skripty nevedeli pracovať s metadata po importe, objekty by sa síce na mape zobrazili, ale nefungovali by správne z hľadiska hernej logiky.

### 2.3 Rebrík a napojenie na logiku hráča

Samostatný problém predstavovala mechanika lezenia po rebríku. V `Tiled` bola jeho poloha definovaná v dátach mapy, ale samotné správanie hráča pri lezení zostalo riešené na strane `Godot`.

Tento princíp je zachytený na nasledujúcej schéme:

![Tiled ladder integration](shema%20git/tiled3.png)

Zo strany `Tiled` sa do úrovne prenášajú údaje o umiestnení rebríka. V samotnej scéne `Godot` sa však využíva objekt `ladder_area`, ktorý je prepojený so skriptom `ladder_area.gd`. Hráčsky skript `Player.gd` potom reaguje na vstup do tejto oblasti a aktivuje climbing behavior.

Výhoda tohto riešenia spočíva v tom, že herná mechanika lezenia sa nemusela vytvárať osobitne pre každý editor. `Tiled` určuje polohu a rozloženie objektu v úrovni, ale konkrétne správanie hráča ostáva spravované priamo v hernej logike projektu.

### 2.4 Zhrnutie integrácie Tiled

Integrácia `Tiled` sa v projekte opierala najmä o tieto kroky:

1. import mapy cez `YATI`,
2. vytvorenie scény so základnými vrstvami úrovne,
3. sprístupnenie kolíznej štruktúry cez `generated_world_collision`,
4. úpravu herných skriptov na čítanie metadata,
5. napojenie špecifických prvkov, ako je rebrík, na existujúcu logiku v `Godot`.

V porovnaní s `LDtk` bol tento postup priamočiarejší a rýchlejší. Zároveň však poskytoval menšiu kontrolu nad tým, ako sú logické údaje štruktúrované a spracované po importe, čo sa prejavilo najmä pri zložitejších interaktívnych objektoch.

## 3. Celkový záver

Oba importné prístupy ukazujú, že pri práci s externými editormi nestačí hodnotiť iba pohodlie kreslenia mapy. Rovnako dôležité je, čo sa deje po importe v hernom engine.

V projekte `Prežiť po` sa ukázalo, že:

1. `LDtk` poskytol najlepšiu štruktúru dát a logických objektov, ale vyžadoval najviac dodatočných post-import úprav.
2. `Tiled` umožnil rýchlejší a jednoduchší prenos základnej štruktúry úrovne do `Godot`, no pri práci s logickými väzbami sa viac spoliehal na metadata a následnú adaptáciu skriptov.
3. V oboch prípadoch zohrávala kľúčovú úlohu vlastná logika projektu, ktorá importované údaje transformovala na funkčný herný level.

Práve z tohto dôvodu bolo pri praktickom porovnaní potrebné sledovať nielen samotný editor, ale celý reťazec od návrhu mapy až po jej plné zapojenie do hry.
