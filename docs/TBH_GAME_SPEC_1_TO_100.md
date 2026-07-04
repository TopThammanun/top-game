# TBH: Task Bar Hero - Game Spec 1-100

**สถานะเอกสาร:** Draft สำหรับ pre-production  
**Source of truth ด้าน setting:** `project_main_setting.md`  
**Engine:** Godot 4.x  
**โปรเจกต์เกม:** TBH: Task Bar Hero  
**ชื่อโลก/แฟนตาซี:** Whisker Realm / Purralia  
**แนวเกม:** Idle + Turn-based RPG แบบเล่นเพลิน ไม่รบกวนเวลา  

## หลักที่ห้ามหลุด

- เกมต้องยึดโลก **Purralia** เป็น setting หลัก: โลกถูกทอจาก **Yarnthread** บนผืน **Great Weave** และกำลังถูกภัย **The Unravel** คลายเส้นด้ายชีวิต
- ปาร์ตี้หลักคือ **อัศวินแมว 4 ตัว** จากตระกูล Felikin หลายสาย โดยมีบทบาท Front/Middle/Rear ชัดเจน
- Core feeling คือ **cozy medieval fantasy**, น่ารัก, อบอุ่น, มีภัยจริงจังพอให้ผจญภัย แต่ไม่ใช่ dark fantasy
- เสาหลักของประสบการณ์คือ **Sound Design** และ **Cuteness** ต้องถูกคิดพร้อม gameplay ไม่ใช่ polish ช่วงท้าย
- โมเดลรายได้ต้องเป็นมิตร: gacha ใจดี, pity โปร่งใส, cosmetics-first, เล่นฟรีจบเนื้อหาได้, เลี่ยง dark pattern
- โครงปัจจุบันต้องใช้ Godot project ที่ init แล้ว และเรียก asset ผ่าน `AssetRegistry` / `data/asset_catalog.json` / `data/asset_shortcuts.json` ให้มากที่สุด

## ขั้นตอนและข้อกำหนด 1-100

### Phase 0 - Foundation

1. กำหนดชื่อโปรเจกต์ฝั่งผลิตเป็น **TBH: Task Bar Hero** และชื่อแฟนตาซีในโลกเกมเป็น **Whisker Realm** โดยใช้ **Purralia** เป็นชื่อทวีป/โลกหลักใน narrative
2. ระบุ `project_main_setting.md` เป็นเอกสารแม่ของ lore, tone, clan, magic, monetization และ sound direction ทุก spec ย่อยต้องไม่ขัดกับไฟล์นี้
3. เก็บ `docs/TBH_GAME_SPEC_1_TO_100.md` เป็น spec เชิงปฏิบัติสำหรับทีมพัฒนาและ AI agent
4. ใช้ Godot 4.x เป็น engine หลัก และเปิดโปรเจกต์จาก `project.godot`
5. ห้ามย้าย asset ต้นฉบับออกจาก `asset/`; การเข้าถึง asset ให้ผ่าน catalog และ shortcut แทน direct path เมื่อเป็นไปได้
6. ใช้ `data/asset_catalog.json` เป็นฐานข้อมูล asset ทั้งหมด และ regenerate ด้วย `tools/generate_asset_catalog.ps1` เมื่อมีการเพิ่ม/เปลี่ยนชื่อ asset
7. ใช้ `data/asset_shortcuts.json` สำหรับชื่อ role ที่คงที่ เช่น `unit.player_idle`, `map.default_tilesheet`, `ui.taskbar_panel`
8. แยกงาน scene ตามโฟลเดอร์: `scenes/main`, `scenes/maps`, `scenes/ui`
9. แยก script ตามโฟลเดอร์: `scripts/autoload`, `scripts/main`, `scripts/maps`, `scripts/ui`
10. แยก data/resource ในอนาคตไว้ที่ `resources/units` และ `resources/commands`

### Phase 1 - World And Story

11. สร้าง world bible ฉบับต่อยอดจาก `project_main_setting.md` โดยคงแกน Purralia, Great Weave, Yarnthread, The First Weaver และ The Unravel
12. กำหนดเป้าหมายเรื่องหลัก: ผู้เล่นคือ **Threadbound** ผู้รวมปาร์ตี้อัศวินแมวเพื่อทอโลกที่กำลังคลายกลับคืน
13. ใช้ภัย **The Unravel** เป็นศัตรูเชิงธีม: ความว่างเปล่า, ด้ายคลาย, ขนพันยุ่ง, สีซีดจาง, ความทรงจำขาดหาย
14. กำหนดโครงเรื่องบทแรกที่ **Emberhearth / Pawmont** เป็น tutorial region และฐานของ Order of the Whisker
15. ให้ **The Great Hearth** เป็น landmark สำคัญของบทแรกและเป็นภาพจำของความอบอุ่น
16. กำหนดบทสองที่ **Silkspiredale** เพื่อเปิดระบบเวท Threadweaving และตัวละครสาย mage/support
17. กำหนดบทสามที่ **Mewrrowmarsh / Tuna Coast** เพื่อเปิดระบบ resource, fishing-flavored rewards, และ NPC พ่อค้า
18. กำหนดบทสี่ที่ **Frostmane Reach** เพื่อเปิด healer, defense challenge, และ cozy winter mood
19. กำหนดบทท้าย/late game ที่ **The Unwoven Wastes** เป็นพื้นที่ที่โลกเริ่มคลายเป็นเส้นด้าย
20. เขียน tone guide ว่าเกมต้องอบอุ่น whimsical และมีมุกเบา ๆ ได้ แต่ต้องไม่ทำให้ภัย The Unravel ดูไร้น้ำหนัก

### Phase 2 - Playable Clans And Characters

21. ใช้ **Felikin** เป็นเผ่าผู้เล่นหลัก และให้เผ่าอื่นเป็น NPC, support system, vendor, ally หรือ monster faction
22. กำหนด 6 clan playable ตาม setting: Maincoon/Ironmane, Siamheart/Voicecasters, Persephone/Silkpaw, Bengalis/Wildstripe, Ragdollan/Cloudfur, Shorthold/Emberpaw
23. Clan Maincoon/Ironmane ต้องเป็น tank/front ที่ตัวใหญ่ ใจดี ภักดี และเป็นภาพจำของอัศวิน
24. Clan Siamheart/Voicecasters ต้องเป็น magic DPS หรือ caster ที่ใช้เสียงร้องและ Threadweaving เป็นเอกลักษณ์
25. Clan Persephone/Silkpaw ต้องเป็น support/buffer ที่สง่างาม เงียบ และเชื่อมกับขุนนาง/นักปราชญ์
26. Clan Bengalis/Wildstripe ต้องเป็น ambush DPS ที่เร็ว คล่อง และมี burst window ชัดเจน
27. Clan Ragdollan/Cloudfur ต้องเป็น healer/rear ที่นุ่มนวล ปลด debuff และรักษาทีม
28. Clan Shorthold/Emberpaw ต้องเป็น balanced starter ที่เป็นมิตร ใช้สอนระบบพื้นฐาน
29. ตัวละคร starter 4 ตัวแรกควรครอบคลุม tank, DPS, support, healer เพื่อให้ผู้เล่นเข้าใจ party comp ทันที
30. ทุกตัวละครต้องมี display identity 3 ชั้น: clan, combat role, cute hook เช่น ปลอกคอ, ท่าทาง, เสียงเฉพาะ

### Phase 3 - Core Loop

31. Core loop หลักคือ เข้าเกม, เก็บ AFK reward, เปิด/รับ loot, อัปเกรดปาร์ตี้, ดัน wave หรือบทถัดไป, แล้วกลับไป idle ต่อ
32. Moment-to-moment loop ต้องให้ผู้เล่นมีสิ่งดี ๆ เกิดขึ้นทุก 2-3 วินาทีในช่วง active session
33. การต่อสู้ต้องเป็น auto-battle เป็นฐาน เพื่อรักษาแรงบันดาลใจจาก Task Bar Hero
34. ผู้เล่นต้องแทรกแซงได้ด้วยคำสั่งสำคัญ เช่น trigger skill, swap focus target, use item, claim burst reward
35. Session แรกต้องเล่นได้ใน 5 นาทีและจบด้วยความรู้สึก "อยากเล่นต่ออีกหนึ่งรอบ"
36. Session ปกติควรอยู่ที่ 3-10 นาที แต่เกมต้องเปิดค้างไว้ได้โดยไม่กดดัน
37. Offline progression ต้องให้รางวัลชัดเจนโดยไม่ทำให้ active play ไร้ค่า
38. AFK chest ต้องมีจังหวะเปิดที่ satisfying ทั้งภาพ เสียง และตัวเลข reward
39. ห้ามสร้าง progression wall ชันเกินไปแบบผู้เล่นรู้สึกติดเพราะต้องจ่ายเงิน
40. ถ้า retention หรือตัวชี้วัดบอกว่า loop น่าเบื่อ ให้แก้ reward cadence ก่อนเพิ่ม feature ใหม่

### Phase 4 - Combat System

41. ปาร์ตี้มาตรฐานมี 4 ตัว แบ่งตำแหน่ง Front, Middle, Rear
42. Combat ต้องรองรับ formation พื้นฐาน: 1 tank, 1-2 DPS, 1 support/healer
43. ศัตรูต้องมาเป็น wave และมี wave milestone ที่ให้ reward/เสียง/visual ชัดเจน
44. แต่ละตัวละครมี basic action อัตโนมัติ, passive, และ ultimate/skill ที่ผู้เล่นกดได้หรือ auto-cast ได้
45. Skill timing ต้องไม่ซับซ้อนเกินไปสำหรับ idle game แต่ต้องมีพื้นที่ให้ optimize build
46. ใช้ affinity ของ Threadweaving เป็นระบบธาตุ: Emberweave, Tideweave, Galeweave, Stoneweave, Hushweave
47. Hushweave ต้องเป็นพลังต้องห้ามหรือพลังศัตรูหลักที่ผูกกับ The Unravel
48. Boss fight ต้องมี telegraph สั้น ๆ และหน้าต่างให้ผู้เล่นกดตอบสนอง
49. Combat UI ต้องแสดง HP, cooldown, ultimate readiness และ loot feed โดยไม่รบกวน taskbar feel
50. MVP combat ต้องมีอย่างน้อย 10 wave, 1 mini-boss, 1 boss และ replay ได้เพื่อ farm reward

### Phase 5 - Map And Taskbar Experience

51. หน้าจอหลักต้องแบ่งเป็น map/play surface และ taskbar/command surface ตาม starter project
52. Map บทแรกต้องใช้ asset จาก `map.default_tilesheet` หรือ tilesheet ใน catalog ที่เหมาะกับ Emberhearth
53. UI taskbar ต้องใช้ asset shortcut เช่น `ui.taskbar_panel`, `ui.slot_empty`, `ui.button_normal`, `ui.hp_orb`
54. Taskbar คือพื้นที่หลักของการสั่งงาน: skill, inventory, upgrade, quest, reward claim
55. Map view ต้องอ่านง่ายแม้ผู้เล่นไม่โฟกัสตลอดเวลา
56. ถ้าเพิ่ม TileMapLayer ให้ทำเป็น scene แยกใน `scenes/maps/` ไม่ฝังทุกอย่างไว้ใน `main.gd`
57. ถ้าเพิ่ม UI reusable ให้สร้างใน `scenes/ui/` เช่น `taskbar.tscn`, `command_slot.tscn`, `resource_orb.tscn`
58. Visual style ต้องคง pixel/cozy medieval จาก asset pack และไม่ผสมสไตล์ที่ clash
59. UI ต้องไม่มีข้อความอธิบายยืดยาวบนหน้าจอเล่นจริง ให้ใช้ icon, tooltip และ feedback แทน
60. Main prototype ต้องโหลด asset ผ่าน `AssetRegistry` เพื่อให้ AI เปลี่ยน asset ได้โดยแก้ shortcut ไม่ใช่แก้ทุก scene

### Phase 6 - Progression And Economy

61. Character progression ต้องมี level, ascension/star, skill level และ role growth ที่เข้าใจง่าย
62. Account/meta progression ต้องมี Rune/Talent Tree ที่ให้โบนัสถาวรและปลดระบบใหม่ทีละขั้น
63. Base progression ให้ใช้ **The Loomstead** เป็นฐานผลิต resource และ landmark buff
64. Equipment ต้องมีช่องหลักอย่างน้อย weapon, armor, accessory/collar, charm
65. Item rarity ใช้ลำดับ Common, Rare, Epic, Legendary, Ancient/Mythic โดยคุม power curve ไม่ให้พัง
66. Equipment affix ต้องสนับสนุน build optimization เช่น cooldown, crit, healing, shield, offline reward
67. Craft/upgrade system ต้องตีความเป็นการ "ทอ/ซ่อมด้าย" เพื่อให้ mechanic อยู่ใน lore
68. Reward ต้องมีทั้ง short-term drop, medium-term upgrade, long-term collection
69. Currency ต้องแยก soft currency, premium currency, gacha ticket, craft material, event token ให้ชัด
70. Economy ต้องมี sink ที่ดีแต่ไม่บีบ เช่น upgrade, cosmetic crafting, reroll affix, base decoration

### Phase 7 - Collection, Gacha And Monetization

71. Gacha ต้องใจดีและโปร่งใส: แสดง rate, มี pity, มีทางสะสมตัวจาก shard/event/exchange
72. ผู้เล่น F2P ต้องเคลียร์เนื้อเรื่องหลักได้โดยไม่ต้องจ่าย
73. Premium spending ต้องเน้น convenience, cosmetics, collection และ battle pass value ไม่ใช่ซื้อชัยชนะตรง
74. Battle Pass ต้องมี free track ที่ดีพอ และ premium track ที่เพิ่มความคุ้มค่าโดยไม่บังคับ
75. Cosmetic shop ต้องขายปลอกคอ, หมวก, สีขน, effect, profile flair และ base decoration
76. Rewarded ads ถ้ามี ต้อง optional และ framed เป็นสิ่งที่ NPC/แมวนำมาเสนอ ไม่ใช่ pop-up ขัดจังหวะ
77. ห้ามใช้ dark pattern เช่น timer หลอก, pop-up ถี่, subscription ยกเลิกยาก, หรือ progression wall ตั้งใจ
78. Banner gacha ต้องมี duplicate handling ที่ยุติธรรม เช่น shard, pity counter, exchange currency
79. Store ต้องเปิดทีละชั้นตาม player maturity เพื่อลด analysis paralysis ช่วงต้นเกม
80. ทุก monetization decision ต้องผ่านคำถาม: "ยัง cozy, ใจดี, และเล่นฟรีจบได้ไหม"

### Phase 8 - Sound, Music And Game Feel

81. Sound design ต้องเริ่มตั้งแต่ prototype ไม่ใช่รอ vertical slice
82. เพลงต้องเป็น cozy medieval fantasy ใช้ lute, harp, recorder, frame drum, piano หรือ nylon guitar ตาม direction
83. Adaptive music ต้องรองรับ vertical layering เพื่อไม่ให้ล้าหูเมื่อเปิดเกมนาน
84. SFX ทุก interaction สำคัญต้อง tight, tactile และมี variation โดยเฉพาะ click, reward, loot, level up, chest
85. Cat voice ต้องมีชุดเสียงสั้น ๆ เช่น mya, nya, mrr, prr และปรับ pitch ตามบุคลิก
86. Purr ambient ต้องเป็น signature layer ที่เบาและเปิด/ปิดได้จาก settings
87. Reward audio ต้องมีชั้นเสียง 3-5 ระดับสำหรับ drop เล็ก, rare drop, level up, chest, boss clear
88. Combat soundscape ต้อง escalate เมื่อ wave ใหญ่หรือ combo ชัด แต่ไม่กลบ UI feedback
89. Sound settings ต้องมี volume แยก master, music, SFX, voice, ambient
90. Benchmark สำคัญ: ผู้เล่นต้องรู้สึกว่าเปิดหีบ, เก็บของ, และ level up "น่าฟังซ้ำ"

### Phase 9 - Content Plan And Milestones

91. Prototype 0-3 เดือนต้องมีบท Emberhearth, party 4 ตัว, 10 wave, 1 boss, AFK reward, basic taskbar UI
92. Prototype ต้องมี 6 clan ตัวอย่างอย่างน้อย clan ละ 1 ตัว แม้บางตัวจะเป็น placeholder
93. Prototype ต้องมี asset-backed UI จาก catalog จริง ไม่ใช้กล่อง placeholder ทั้งหมด
94. Vertical slice 3-6 เดือนต้องเพิ่ม gacha ใจดี, pity, equipment, cosmetics, offline cap และ adaptive audio prototype
95. Vertical slice ต้องมี 2 region playable: Emberhearth และ Silkspiredale หรือ Tuna Coast
96. Soft launch 6-10 เดือนต้องมีอย่างน้อย 3 region, daily/weekly, guild หรือ social-lite, battle pass และ event loop
97. KPI เริ่มต้น: session แรก 5 นาทีอยากเล่นต่อ, Day-1 retention >40%, Day-7 retention >20% ใน test cohort
98. Threshold ปรับแผน: ถ้า Day-2 retention <20% ให้แก้ core loop/reward cadence ก่อนแก้ monetization
99. Threshold ปรับ balance: ถ้าผู้เล่นบ่น progression wall ให้ลด exponential scaling และเพิ่มทางเลือก upgrade ที่มองเห็นได้
100. Definition of Done ของ pre-production คือมี playable Godot prototype, world bible ที่อัปเดต, asset workflow ผ่าน catalog, combat loop 1 region, taskbar UI ใช้งานได้, sound prototype, และ spec ย่อยพร้อมให้แตกเป็น issue

## ไฟล์ที่ AI ควรอ่านก่อนทำงานรอบถัดไป

- `project_main_setting.md` - setting/lore หลัก
- `docs/TBH_GAME_SPEC_1_TO_100.md` - spec เชิงปฏิบัติ 1-100
- `docs/PROJECT_IDENTITY.md` - ชื่อ canonical และกติกาการใช้ชื่อ
- `data/project_identity.json` - identity แบบ machine-readable
- `docs/DESIGN_SOURCE_OF_TRUTH.md` - authority order, engine contract, asset contract
- `docs/world/WORLD_BIBLE.md` - world bible สำหรับ Purralia
- `docs/world/STORY_AND_REGIONS.md` - campaign spine และ region briefs
- `docs/world/TONE_GUIDE.md` - tone guide สำหรับข้อ 20
- `data/world/regions.json` - region briefs แบบ machine-readable
- `docs/ASSET_MAP.md` - วิธีเลือกและเรียกใช้ asset
- `data/asset_shortcuts.json` - alias ที่ควรใช้ใน code
- `data/asset_catalog.json` - catalog asset ทั้งหมด
- `docs/TBH_PROJECT_BRIEF.md` - โครง Godot starter ปัจจุบัน
- `docs/SPEC_PROGRESS_1_TO_100.md` - index หลักของหลักฐานว่า spec 1-100 ถูก map แล้ว
- `docs/SPEC_PROGRESS_21_TO_100.md` - tracker สำหรับข้อ 21-100

## งานถัดไปที่ควรแตกเป็น issue

- Issue 1: สร้าง `MapView` scene สำหรับ Emberhearth จาก `map.default_tilesheet`
- Issue 2: สร้าง `Taskbar` scene ที่ใช้ `ui.taskbar_panel`, slot, button และ resource orb
- Issue 3: สร้าง unit data resource สำหรับ starter party 4 ตัว
- Issue 4: สร้าง combat loop 10 wave พร้อม mini-boss และ boss
- Issue 5: สร้าง AFK reward chest พร้อม reward audio placeholder
- Issue 6: สร้าง first-pass sound cue list ตามข้อ 81-90
