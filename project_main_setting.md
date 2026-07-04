# เอกสารออกแบบเกม (Game Design Document) — โฟกัส World Setting
# โปรเจกต์: "Whisker Realm" (ชื่อแฟนตาซีหลัก) — โลกแมวยุคกลางแฟนตาซี
## เกม Idle + Turn-based RPG แนว "เล่นแล้วเพลิน"

**เวอร์ชันเอกสาร:** 1.0 (ร่างเพื่อการพัฒนา) — 3 กรกฎาคม 2026

---

## TL;DR (สรุป 3 บรรทัด)
- **นี่คือเกม Idle + Turn-based RPG** ที่ผู้เล่นสร้างปาร์ตี้ "อัศวินแมว" 4 ตัวจากหลายเผ่าพันธุ์ ออกสู้มอนสเตอร์แบบกึ่งอัตโนมัติในโลกแฟนตาซียุคกลางที่น่ารักและผ่อนคลาย โดยมี **เสียง (Sound Design) และความน่ารัก (Cuteness) เป็นเสาหลักสองต้น**
- **โลก "Purralia" (เพอร์ราเลีย)** เป็นทวีปที่แมวหลายเผ่า (อิงจากสายพันธุ์แมวจริง) อยู่ร่วมกับเผ่าอื่น ๆ ต่อสู้กับ "The Unravel" — ภัยจากขนพันกัน/ความว่างเปล่าที่คุกคาม "เส้นด้ายแห่งชีวิต" (Yarnthread) ที่ทอโลกขึ้นมา
- **โมเดลรายได้ที่แนะนำ:** gacha ใจดีแบบ Cookie Run: Kingdom + Battle Pass + cosmetics โดยเน้นความ "เล่นฟรีจบได้-ไม่กดดัน" ให้เข้ากับโทนอบอุ่น cozy และหลีกเลี่ยง dark pattern

---

## Key Findings (ข้อค้นพบสำคัญจากการวิจัยเกมอ้างอิง)

1. **TBH: Task Bar Hero** — จุดแข็งคือ "เกมทั้งเกมอยู่ในแถบ taskbar" ปาร์ตี้ auto-battle เอง ผู้เล่นทำทุกอย่างระหว่างการสู้ (เลเวลฮีโร่ ใช้ rune คราฟต์ของ) มีระบบ Rune Tree เป็น long-term progression, Hero-dric Cube ปรับสเตตัสไอเทม, ของดรอปกว่า 500 ชิ้น 5 ระดับความหายาก (Common→Cosmic) **บทเรียนสำคัญ:** ความรู้สึก "ไม่รบกวนเวลา" + สะสมของ + optimize build คือหัวใจ แต่ต้องระวัง late-game grind ที่ชันเกินไป (เจอ progression wall ที่ Lv.65 / Wave 200) ซึ่งทำให้รีวิวเป็น Mixed
2. **Cookie Run: Kingdom** — art direction เน้น shape-based design + kawaii, ทีม Art และ Story อยู่กลุ่มเดียวกัน (Kingdom Art Creative Group) ทำให้ narrative+visual แน่น มี "Compendium of the Cookie World" เอกสาร lore กว่า 300 หน้าเป็นฐานราก (และ art collection ฉบับตีพิมพ์ 200 หน้าพร้อม backstory) โลกชื่อ Earthbread มี 5 อาณาจักรของ 5 Ancient Heroes ที่แต่ละคนได้รับ Soul Jam gacha ใจดีมาก (อัตราดรอปสูง) จนทำรายได้ระดับ "ราวหนึ่งในสี่พันล้านดอลลาร์จากยอดดาวน์โหลดเพียง 22 ล้าน" (≈ >$10 ต่อดาวน์โหลด, Deconstructor of Fun เม.ย. 2022) DAU/MAU >30% เก็บเงินจากคอร์แฟนที่ภักดี ไม่ใช้โฆษณาเลย
3. **Fate/Grand Order** — ระบบสู้ turn-based ผสม Command Card 3 สี (Buster=ดาเมจ, Arts=ชาร์จ NP, Quick=critical stars) แต่ละ Servant มี 5 การ์ด สับรวมกันแล้วแจก 5 ใบต่อเทิร์นเลือก 3 ใบ มี Chain/Brave Chain, ระบบ class advantage, Noble Phantasm (ท่าไม้ตาย), party 6 ตัว (3 หน้า 3 สำรอง) เก็บเงินผ่าน gacha Saint Quartz
4. **Vampire Survivors** — flow state มาจาก input น้อยสุด (แค่ขยับ) + reward cadence ถี่มาก (แทบไม่มีช่วงว่าง) + power fantasy 0→100 ทุกรอบ + "จังหวะแม่เหล็กดูดเพชร" ที่เป็น dopamine hit + หีบสมบัติเหมือนสล็อตแมชชีน — ผู้ออกแบบ Luca Galante ใช้เวลาส่วนใหญ่ในอาชีพก่อนหน้าทำเกมสล็อตบนมือถือให้ "บริษัทพนันใหญ่" และเล่าว่าสล็อตเกมหนึ่ง "มี jingle เพราะ ๆ ตอนหีบสมบัติเปิด" ซึ่งเป็นแรงบันดาลใจตรงของแอนิเมชันเปิดหีบใน VS; art/sound/UI อยู่ระดับความละเอียดเดียวกัน = ดูตั้งใจ
5. **เกมแมว (Cat Quest / Neko Atsume / Stray)** — Cat Quest ใช้โลก "Felingard" อาณาจักรแมว เต็มไปด้วยมุกเล่นคำ (Catpital, meowntain) ปรัชญา "cozy fantasy ที่ใครก็เล่นได้"; Neko Atsume พิสูจน์ว่าระบบเรียบง่าย + น่ารัก + guilt-free monetization (ดูโฆษณาที่แมวเอามาให้ หรือซื้อปลา) = ยอดดาวน์โหลดกว่า 33 ล้านทั้งซีรีส์ (ตามหน้าร้าน App Store ทางการของ Neko Atsume 2 โดย Hit-Point) ธีมหลักคือ "healing/looseness"
6. **Idle/Gacha hybrid best practices** — AFK Arena พิสูจน์ว่า XP ได้จากการเล่น+AFK timer เท่านั้น ไม่ขายตรง, VIP ให้ประโยชน์ทางอ้อม, Battle Pass ต้นทุนต่ำ; เกม idle ส่วนใหญ่เสียผู้เล่น 80% ภายใน Day 2 เพราะ front-load monetization และไม่ยึดธีม; ควรใช้ pity system, เปิดเผยอัตราดรอป, เลี่ยง dark pattern
7. **Sound Design เกม cozy** — Unpacking (Jeff & Angela van Dyck) ใช้ Foley กว่า 14,000 ไฟล์ WAV (ตาม Audiokinetic) และชนะ Game Developers Choice Award สาขา Best Audio 2022 โดยแข่งกับเกม AAA, เสียงต้อง "tight/tactile" ไม่หน่วง; Animal Crossing (Kazumi Totaka) ปรัชญา "ไม่มีเสียงที่ไม่จำเป็น" + ภาษา "Animalese"; Spiritfarer (Max LL) ใช้เปียโน+กีตาร์ไนลอนเป็นเสียง "cozy"; A Short Hike (Mark Sparling) ใช้ vertical layering 5 ชั้นกันความล้าหูในเซสชันยาว

---

## 1. WORLD SETTING & LORE (โฟกัสหลัก)

### 1.1 ชื่อโลกและภาพรวม
**ชื่อโลก: "Purralia" (เพอร์ราเลีย)** — ทวีปใหญ่ที่ลอยอยู่บนผืน "Great Weave" (ผืนทอใหญ่) เชื่อกันว่าทั้งโลกถูก "ทอ" ขึ้นจากเส้นด้ายวิเศษที่เรียกว่า **"Yarnthread" (ยาร์นเธรด / เส้นด้ายแห่งชีวิต)** โดยเทพโบราณนามว่า **"The First Weaver" (ช่างทอปฐม)** ซึ่งเป็นแมวยักษ์ในตำนาน แนวคิดนี้ผสาน motif "แมวเล่นไหมพรม" เข้ากับ world-building แบบ "โลกคือผืนผ้าที่ทอได้/คลายได้" (สื่อภาพ tapestry แบบ Cat Quest แต่ยกระดับเป็นกลไกเรื่องราว)

โทนโดยรวม: **medieval fantasy ที่อบอุ่น สดใส whimsical** — ปราสาทหินอบอุ่น ทุ่งหญ้า ตลาดนัด โคมไฟยามค่ำ ไม่ใช่ dark fantasy แต่มี "ภัยคุกคาม" ที่จริงจังพอให้มีเหตุผลออกผจญภัย

### 1.2 ภูมิศาสตร์และอาณาจักร/แว่นแคว้น
Purralia แบ่งเป็น 5 ภูมิภาคหลัก (แต่ละภูมิภาคเป็นทั้ง lore hub และ "โลก/บท" ของเกม idle progression):

1. **Emberhearth (เอมเบอร์เฮิร์ธ)** — ราชธานีกลาง อาณาจักรอัศวินหลัก ปราสาทหินอบอุ่นริมเตาผิงยักษ์ "The Great Hearth" ที่ไม่เคยดับ เป็นศูนย์กลางของ Order of the Whisker (คณะอัศวินแมว) เมืองหลวงชื่อ **"Pawmont" (พอว์มอนต์)**
2. **Silkspiredale (ซิลค์สไปร์เดล)** — หุบเขาหอคอยผ้าไหม ดินแดนของเวทมนตร์และนักปราชญ์ หอคอยสูงที่ "ปั่นด้ายเวท" หมอกนุ่มลอยตลอดเวลา
3. **Mewrrowmarsh / Tuna Coast (ชายฝั่งทูน่า)** — ชายฝั่งประมง หมู่บ้านชาวเรือแมว ท่าเรือ ตลาดปลา บรรยากาศ cozy seaside
4. **Frostmane Reach (ฟรอสต์เมนรีช)** — ดินแดนเหนือหิมะ ภูเขาน้ำแข็ง เผ่านักรบขนหนา บรรยากาศ "eternal winter" แบบอบอุ่น (ผิงไฟในกระท่อม)
5. **The Unwoven Wastes (ดินแดนที่ด้ายคลาย)** — ภูมิภาคชายขอบที่ถูก "The Unravel" กัดกิน สีซีดจาง โครงสร้างโลกเริ่มคลายเป็นเส้นด้าย เป็น end-game zone

รอบทวีปมี **"The Nine Seas of Milk"** (ทะเลน้ำนมเก้าผืน) ล้อกับ world-building ของ Earthbread ที่มีมหาสมุทรหลายผืน — เพิ่มความ whimsical

### 1.3 เผ่าพันธุ์ในโลก (Races)
โลกไม่ได้มีแค่แมว แต่แมวเป็นเผ่าเด่น (playable) เผ่าอื่นเป็น NPC / พันธมิตร / ศัตรูบางส่วน:
- **Felikin (เฟลิคิน)** — เผ่าแมว (เผ่าหลัก ผู้เล่นควบคุม) แบ่งเป็นหลายตระกูล (clans) ดูหัวข้อ 1.4
- **The Woolfolk (วูลโฟล์ค)** — เผ่าแกะ/สัตว์ขนปุย ช่างทอและพ่อค้า สังคมสงบสุข เป็นแหล่งเศรษฐกิจ/คราฟต์
- **The Houndsworn (ฮาวนด์สวอร์น)** — เผ่าสุนัข อดีตคู่ปรับ (echo ของ Cat Quest II: cats vs dogs) ตอนนี้เป็นพันธมิตรอึดอัด ๆ นักรบเกียรติยศ
- **Sugar Gnomes / Tinkerkin (ทิงเคอร์คิน)** — เผ่าจิ๋วช่างประดิษฐ์ (echo Sugar Gnomes ของ CRK) ช่วยสร้าง/อัปเกรดฐาน
- **The Mothkin (ม็อธคิน)** — เผ่าผีเสื้อกลางคืน/แมลงปีก อาศัยใน Silkspiredale เกี่ยวข้องกับเวทมนตร์และความลับโบราณ
- **The Ratterlings (แรทเทอร์ลิง)** — เผ่าหนู กลุ่มสีเทา บางส่วนเป็นโจร บางส่วนเป็นพ่อค้าข้อมูล (moral grey)

### 1.4 การออกแบบเผ่า/ตระกูลแมว (Cat Tribes/Clans) — ส่วนสำคัญ
เผ่าแมวแบ่งเป็น **6 ตระกูล (Clans)** อิงจากสายพันธุ์แมวจริง แม็ปเข้ากับ archetype แฟนตาซี + gameplay identity แต่ละตระกูลมีวัฒนธรรม, บ้านเกิด, เอกลักษณ์ภาพ และบทบาทในเกม:

| ตระกูล (Clan) | สายพันธุ์อ้างอิง | Archetype | บ้านเกิด | Gameplay Identity | บุคลิก/วัฒนธรรม |
|---|---|---|---|---|---|
| **Clan Maincoon / "Ironmane"** | Maine Coon | อัศวิน/แทงค์ | Emberhearth | Tank (Front) HP สูง ป้องกันทีม | ตัวใหญ่ ใจดี "gentle giant" ภักดี เป็นแกนอัศวิน |
| **Clan Siamheart / "Voicecasters"** | Siamese | เมจ/ผู้ร่ายเวทเสียง | Silkspiredale | Magic DPS (Middle) ร่ายเวทด้วยเสียงร้อง | ช่างพูด ฉลาด สังคมจัด เสียงดัง (vocal) |
| **Clan Persephone / "Silkpaw"** | Persian | ซัพพอร์ต/ขุนนาง | Silkspiredale | Support/Buffer (Rear) สงบ สง่างาม | เงียบสงบ สง่า ขุนนางเก่าแก่ ชอบความสงบ |
| **Clan Bengalis / "Wildstripe"** | Bengal | นักล่า/แอสแซสซิน | Mewrrowmarsh/ป่า | Ambush DPS (Middle) เบิร์สต์แรง คล่องแคล่ว | พลังงานสูง อยากรู้อยากเห็น ดุดันแบบเสือดาว |
| **Clan Ragdollan / "Cloudfur"** | Ragdoll | ฮีลเลอร์/นักบวช | Frostmane (วัด) | Healer (Rear) ฟื้น HP ปลด debuff | อ่อนโยน ใจเย็น รักสงบ "ตัวนิ่มที่สุด" |
| **Clan Shorthold / "Emberpaw"** | British/American Shorthair | นักผจญภัยรอบด้าน | Tuna Coast | Balanced Charge (Front/Middle) | ผ่อนคลาย เข้ากับทุกคน เป็นมิตร ตัวเริ่มต้น |

หมายเหตุออกแบบ: การแม็ปสายพันธุ์→บุคลิกอิงพฤติกรรมจริง (Siamese "ช่างพูด/vocal", Maine Coon "gentle giant", Persian "สงบ/สง่า", Ragdoll "ตัวนิ่ม/ยอมให้อุ้ม", Bengal "พลังงานสูง/เหมือนเสือดาวจิ๋ว") ทำให้ตัวละครมีเหตุผลรองรับและ "อ่านออก" ทันที

### 1.5 ระบบเวทมนตร์ (Magic System)
เวทมนตร์ใน Purralia เรียกว่า **"Threadweaving" (การทอด้าย)** — ทุกสรรพสิ่งเชื่อมด้วย Yarnthread นักเวทคือผู้ที่ "มองเห็นและดึงเส้นด้าย" ได้ แบ่งเป็น 5 สาย (schools) ที่ผูกกับกลไกสู้ (elemental/affinity):
- **Emberweave (ด้ายไฟ)** — ดาเมจ/เผา
- **Tideweave (ด้ายน้ำ/นม)** — ฮีล/ไหลลื่น
- **Galeweave (ด้ายลม)** — ความเร็ว/critical
- **Stoneweave (ด้ายดิน)** — ป้องกัน/โล่
- **Hushweave (ด้ายเงียบ/ความว่าง)** — เวทต้องห้าม ผูกกับ The Unravel

หลักการ: เวทไม่ใช่ "พลังทำลาย" แต่เป็น "การทอ/ซ่อม/คลาย" โลก — สอดคล้องโทน cozy (แม้แต่การสู้ก็คือการ "ซ่อมด้ายที่ขาด") **เสียงร่ายเวทควรนุ่ม-น่าฟัง** (echo Siamese ว่าร่ายเวทด้วยเสียง)

### 1.6 ประวัติศาสตร์/ไทม์ไลน์ และความขัดแย้งหลัก
**Timeline (แบ่งเป็นยุค):**
- **ยุคที่ 1 — The Great Weaving (การทอครั้งใหญ่):** First Weaver ทอโลกและสรรพชีวิตจาก Yarnthread สร้าง "Nine Great Spindles" (แกนปั่นด้ายเก้าอัน) เป็นเสาค้ำโลก
- **ยุคที่ 2 — The Purring Age (ยุคครืนคราง/ยุคทอง):** อารยธรรมเจริญ 6 ตระกูลแมวตั้งถิ่นฐาน สร้าง Order of the Whisker
- **ยุคที่ 3 — The First Unraveling (การคลายด้ายครั้งแรก):** เกิด **"The Unravel"** — พลังความว่างเปล่าที่ "คลาย" เส้นด้ายโลกให้กลายเป็นขนพันยุ่ง (motif "hairball/ขนพันกัน" = ศัตรู) Spindle บางอันแตก ภูมิภาคชายขอบกลายเป็น Unwoven Wastes เหล่าฮีโร่โบราณเสียสละปิดผนึกไว้ได้ชั่วคราวแล้วหายไป (echo โครงสร้าง Ancient Heroes ของ CRK ที่ต่อสู้ Dark Enchantress Cookie แล้วหายไปพร้อม Soul Jam ที่แตกกระจาย)
- **ยุคที่ 4 — ปัจจุบัน (The Reweaving):** The Unravel กลับมาอีกครั้ง ผู้เล่นคือ **"Threadbound" (ผู้ผูกด้าย)** — อัศวินแมวรุ่นใหม่ที่รวมปาร์ตี้ 4 ตัวออกเดินทาง "ทอโลกกลับคืน" ตามหาแกนปั่นด้ายที่หายและฮีโร่โบราณ

**ทำไมแมวต้องสู้มอนสเตอร์:** มอนสเตอร์คือ "เส้นด้ายที่คลายและพันเป็นก้อน" (Tangleborn) การสู้ = การ "สางด้ายที่ยุ่ง" คืนความเป็นระเบียบให้โลก — ให้เหตุผลเชิงบวก/cozy แทนการฆ่าล้าง

### 1.7 กลุ่มมอนสเตอร์และปรัชญาการออกแบบศัตรู (Monster Factions)
มอนสเตอร์เรียกรวมว่า **"The Tangleborn" (ทังเกิลบอร์น / ผู้เกิดจากด้ายพัน)**:
- **Yarnlings (ยาร์นลิง)** — ก้อนไหมพรมมีตา ศัตรูพื้นฐาน น่ารักแต่กวน (echo ความน่ารักของ Cake Monster ของ CRK)
- **Snarlbeasts (สนาร์ลบีสต์)** — สัตว์ขนพันขนาดกลาง
- **Dust Bunnies / Dustkin** — ก้อนฝุ่นใต้เตียง (มุกแมว) กลุ่มเยอะ
- **The Hollowmews (ฮอลโลว์มิว)** — บอส/ศัตรูชั้นสูง แมวเงาที่ถูก Hushweave กลืน (dark-but-not-evil แบบ Dark Cacao Cookie)
- **The Unravel เอง** — ภัยคุกคามระดับ existential เป็น "ความว่าง" ที่คลายทุกอย่าง (final boss factions)

ปรัชญาออกแบบศัตรู: **"น่ารักแต่มีน้ำหนัก"** — ศัตรูควรดูนุ่ม/ตลก ไม่น่ากลัวเกินไป แต่บอสควรมี pattern/DPS check ให้รู้สึกท้าทาย (เรียนจาก TBH ว่า milestone boss ทุก 100 เวฟช่วยแบ่งจังหวะ แต่ต้องไม่ทำ scaling ชันเกินจนเป็นกำแพง)

### 1.8 แนวทางโทนและอารมณ์ (Tone & Mood Guidelines)
- **Cozy medieval whimsy:** อบอุ่น สดใส สีพาสเทลอิ่ม แสงนุ่ม (echo CRK: สีสด รายละเอียดเยอะ + kawaii)
- **Shape-based cute design:** ออกแบบตัวละครจากรูปทรงพื้นฐาน กลม-นุ่ม (เรียนจาก CRK art philosophy ที่ใช้ basic shapes สร้างตัวละคร)
- **Guilt-free / healing:** ธีมหลักคือ "การซ่อมแซม/ผ่อนคลาย" ไม่ใช่ความรุนแรง (เรียนจาก Neko Atsume: ธีม "looseness & healing")
- **มุกเล่นคำแมว (cat puns):** ชื่อสถานที่/ไอเทมเล่นคำ (Pawmont, meowntain, purr-) แต่ไม่ล้นจนรก (เรียนจาก Cat Quest: Catpital, meowntain)

---

## 2. GAMEPLAY LOOP

### 2.1 Core Loop (moment-to-moment)
ปาร์ตี้แมว 4 ตัว auto-battle มอนสเตอร์แบบ turn-based กึ่งอัตโนมัติ:
- การสู้เดินอัตโนมัติ (auto-attack) แต่ผู้เล่นมี **"จังหวะแทรกแซง"** — เลือกเวลากดปล่อยสกิล/ท่าไม้ตาย (echo FGO: กด NP เมื่อพร้อม, echo AFK Arena: auto แต่เลือกเวลา trigger ult)
- ทุกเวฟที่เคลียร์ = ของดรอป + XP + สกุลเงิน (reward cadence ถี่แบบ Vampire Survivors ที่แทบไม่ปล่อยให้ผู้เล่นว่างเกินไม่กี่วินาที)
- มี "จังหวะ dopamine" เป็นระยะ: หีบสมบัติเปิดพร้อมเสียง/แสง (echo VS treasure chest + jingle), milestone boss ทุก N เวฟ

### 2.2 การผสาน Idle + Turn-based (Auto-battle & Offline)
- **Active play:** เปิดเกมอยู่ = ดรอปเต็ม (echo TBH: chest ดรอปเฉพาะตอนเปิด) เห็นการสู้สวย ๆ ได้แทรกแซง
- **Offline/AFK progression:** ปิดเกม = ได้ XP + gold + วัตถุดิบสะสมตาม timer (echo AFK Arena: AFK timer) แต่ **ของหายาก/ความรู้สึกดีที่สุดอยู่ที่การเปิดเล่นสั้น ๆ** (บทเรียน TBH: 20 นาที active > หลายชั่วโมง offline) — ออกแบบให้ผู้เล่นอยากกลับมา "เก็บของ" วันละไม่กี่ครั้ง
- มี **offline reward cap** ที่สมเหตุสมผล (เช่น 8–12 ชม.) และ "AFK chest" ที่เก็บทีเดียว = จังหวะ dopamine ตอนกลับเข้าเกม

### 2.3 การสร้าง "Flow State" แบบ Vampire Survivors ในบริบท idle turn-based
กลยุทธ์ปรับใช้ 4 ข้อ:
1. **Reward cadence ถี่:** อย่าปล่อยให้มีช่วงว่างนานเกิน 2-3 วินาทีโดยไม่มี "อะไรดี ๆ" เกิดขึ้น (เลเวลอัป, ดรอป, เสียงน่ารัก)
2. **Power fantasy 0→100:** ให้ปาร์ตี้อ่อนตอนต้นรอบ แล้วแข็งขึ้นเรื่อย ๆ ผ่านการอัปเกรด (เห็นตัวเลข/เอฟเฟกต์โตขึ้นชัด)
3. **"จังหวะแม่เหล็กดูดของ":** โมเมนต์เก็บของรวดเดียว (auto-collect ดรอปสะสม) พร้อมเสียง/แอนิเมชันพุ่ง (echo VS magnet moment ที่เป็น "dopamine hit" ชัดเจน)
4. **ความสม่ำเสมอของ art/sound/UI:** ทุกองค์ประกอบอยู่ระดับความละเอียด/สไตล์เดียว (บทเรียน VS: consistent middle > hero asset เดี่ยว)

### 2.4 Session Loop & Meta Loop (daily/weekly)
- **Session loop (ต่อครั้ง 3-10 นาที):** เข้าเกม → เก็บ AFK reward → เปิดหีบ → อัปเกรดแมว/ของ → ดันเวฟ/บทถัดไป → ทำ daily 2-3 อย่าง
- **Daily:** ภารกิจประจำวัน, dungeon พลังงานจำกัด (echo CRK/AFK), gacha ฟรีรายวัน (echo AFK Arena: 10 free summon/วัน)
- **Weekly:** guild boss, event banner, weekly milestone, arena PvP (optional)
- **Meta loop:** สะสม/อัปเกรดแมวหลายเผ่า → ปลดล็อกภูมิภาคใหม่ → ตามเนื้อเรื่อง → สร้าง/ตกแต่งฐาน (echo CRK kingdom building)

### 2.5 ระบบ Progression
- **Party level & แต่ละตัวละคร:** เลเวล, ascension/ดาว (echo AFK/CRK)
- **Rune/Talent Tree:** ปมอัปเกรดถาวร ปลดสล็อต, offline reward, auto-features (echo TBH Rune Tree)
- **Kingdom/Base:** ฐาน "The Loomstead" (ลูมสเตด) ผลิตวัตถุดิบ + landmark buff (echo CRK ที่ landmark ให้ stat buff เช่น HP +15%)
- **Prestige/Reweave:** ระบบรีเซ็ตเพื่อโบนัสถาวร (optional end-game)

---

## 3. CHARACTER & EQUIPMENT SYSTEMS

### 3.1 คลาส/บทบาทของปาร์ตี้ 4 ตัว
ใช้โครงสร้าง Front/Middle/Rear แบบ CRK + role RPG มาตรฐาน ปาร์ตี้ 4 ตัวควรมี:
- **Tank/Front (Guardian):** Clan Maincoon — ดึงดาเมจ, HP สูง, โล่
- **DPS/Middle (Striker):** Clan Bengalis (Ambush เบิร์สต์) หรือ Clan Siamheart (Magic AoE)
- **Support/Buffer (Weaver):** Clan Persephone — buff/debuff
- **Healer/Rear (Mender):** Clan Ragdollan — ฮีล/ปลด debuff

หลักการทีม: 1 แทงค์ + 1-2 DPS + 1 ซัพพอร์ต/ฮีลเลอร์ (echo CRK balanced comp: tank + DPS + healer + support) — แต่เปิดให้ทดลอง comp หลากหลายเพื่อ replay value

### 3.2 การได้ตัวละคร (Acquisition), Rarity, Leveling, Skills
- **Gacha ใจดีแบบ CRK:** อัตราดรอปตัวหายากสูงพอควร, มี **pity system** โปร่งใส (เปิดเผยอัตรา), ได้ตัวจาก event/exchange ไม่ใช่แค่ซื้อ (echo CRK: non-payer ก็สะสมตัวหายากได้ผ่าน coin exchange/event)
- **Rarity tiers:** เสนอ Common → Rare → Epic → Legendary → **Ancient/Mythic** (echo CRK/TBH 5 tiers) + Beast-tier พิเศษสำหรับ end-game
- **Leveling:** XP + วัตถุดิบ + soulstone (ชิ้นส่วนตัวละคร) เพื่อ ascension (echo CRK Soulstones)
- **Skills:** แต่ละตัวมี 1 ท่าไม้ตาย (echo NP) + passive; ผู้เล่นเลือกเวลาปล่อย

### 3.3 ระบบอุปกรณ์ (Equipment)
- **Slots:** อาวุธ, เกราะ, เครื่องประดับ (collar/ปลอกคอแมว!), เครื่องราง — 4-6 ช่อง
- **Rarity + affixes:** ของหลายระดับ, affix สุ่ม (echo TBH: rarity สูง = affix เยอะ, 500+ items)
- **Upgrade/Craft:** ระบบคราฟต์/ปรับสเตตัส (echo TBH Cube) + set bonus
- **Cosmetics/customization:** costume/skin ที่เปลี่ยน visual (echo CRK costumes ให้ stat boost บ้าง) + ปลอกคอ/หมวก/เอฟเฟกต์น่ารัก **เน้น self-expression** — cosmetics คือแกน monetization ที่เป็นมิตร

### 3.4 ความลึกของ Party Customization
- สลับตัว/ตำแหน่ง (formation front/mid/rear)
- Toppings/Runes ต่อตัว (echo CRK toppings)
- Skin + สีขน + accessory (dress-up แมว = จุดขายความน่ารัก)
- ตั้งชื่อแมวเอง + interaction/ลูบหัว (echo Neko Atsume petting = cozy touch)

---

## 4. SOUND DIRECTION (เสาหลักของเกม)

### 4.1 ทิศทางดนตรี (Music Direction)
- **แนว:** cozy medieval fantasy — ใช้ church modes (Dorian, Lydian, Mixolydian, Aeolian) แทน major/minor ตรง ๆ, open fifths, drone/bourdon (เอกลักษณ์เสียงยุคกลาง)
- **เครื่องดนตรี:** lute, Celtic harp, psaltery, recorder, vielle, hurdy-gurdy, frame drum + เพิ่มเปียโน/กีตาร์ไนลอนเป็นเสียง "cozy" (เรียนจาก Max LL/Spiritfarer ที่ระบุว่าเปียโนให้ความรู้สึก "familiar และ cozy")
- **Tempo:** โซน ambient/สำรวจ ~65–90 BPM (ผ่อนคลาย ไม่ล้า), โซนเฉลิมฉลอง/สู้บอส 110–130 BPM
- **Adaptive/vertical layering:** แบ่งเพลงเป็น stem หลายชั้น (เพอร์คัสชัน/คอร์ด/เมโลดี/แอมเบียนต์) เฟดเข้าออกตามสถานการณ์เพื่อ **กันความล้าหูในเซสชัน idle ยาว** — A Short Hike (Mark Sparling) ยืนยันใช้ 5 ชั้น (ชั้น 1 เพอร์คัสชัน, ชั้น 2 เมโลดี, ชั้น 3 คอร์ด, ชั้น 4 เมโลดีแอ็กทีฟน้อยลง, ชั้น 5 คอร์ดทางเลือก) โดยบนภูเขา "ชั้นต่าง ๆ ซ้อนทับกัน" ทำให้เพลง "น่าตื่นเต้นขึ้นเมื่อปีนสูงขึ้น" — สำคัญมากเพราะเป็นเกมที่เปิดค้างนาน
- **ธีมที่จำได้:** เน้นเมโลดีหลักที่ติดหู (Max LL: ชอบ themes ที่จำได้มากกว่า adaptivity ที่จำไม่ได้)

### 4.2 ปรัชญา SFX (Sound Effects)
- **Tight & tactile feedback:** เสียงต้องสั้น กระชับ ไม่หน่วง ตอบสนองทันเฟรม (เรียนจาก Unpacking — Jeff van Dyck, Foley กว่า 14,000 ไฟล์ WAV, ชนะ Game Developers Choice Award สาขา Best Audio 2022 โดยแข่งกับเกม AAA)
- **"ไม่มีเสียงที่ไม่จำเป็น":** มิกซ์แบบเว้นที่ว่าง เสียง reward จึงเด่น (เรียนจาก Animal Crossing — Kazumi Totaka)
- **เสียงแมวน่ารัก (cat voice):** ใช้เทคนิค "gibberish voice" แบบ Animalese — แม็ปตัวอักษร/พยางค์เป็นเสียงสังเคราะห์สั้น เล่นเร็วต่อเนื่อง, ปรับ pitch ตามบุคลิก/อารมณ์/ขนาดตัว (แมวตัวเล็ก pitch สูง) เสียงชุด "mya/nya/mrr/prr" สำหรับพูด/ฮัมเพลง (เรียนจาก K.K. Slider syllable set)
- **ASMR-like polish:** เสียงเก็บของ/เปิดหีบ/เลเวลอัป ทำให้ "น่าฟังซ้ำ" — ใช้ material Foley จริง (เสียงไหมพรม, กระดิ่งปลอกคอ, เสียง purr) มี **หลาย variation สุ่ม** ของเสียงที่ได้ยินบ่อย (footstep, click) กันความน่ารำคาญ

### 4.3 เสียงเสริม flow/idle อย่างไร
- **Reward audio = dopamine loop:** เสียง chime เลเวลอัป/critical/หีบ 3-5 ชั้น เป็น positive reinforcement (มีงานวิจัย peer-reviewed รองรับ: ACM 2024 "Juicy Audio", Springer 2021 "That Sound's Juicy!" ที่พบว่าเสียง juicy เพิ่ม presence/immersion อย่างมีนัยสำคัญ)
- **เสียง purr (ครืนคราง) เป็น ambient signature:** เสียงแมวครางเบา ๆ เป็นชั้นเสียงพื้นหลังที่ผ่อนคลาย = เอกลักษณ์เกม
- **Escalating soundscape ตอนสู้เยอะ:** เมื่อเคลียร์เวฟใหญ่ เสียงซ้อนกันเป็น "ซิมโฟนี" (echo VS late-game audio ที่กลายเป็น "certifiable symphony of sounds") ให้ความรู้สึกทรงพลัง

---

## 5. MONETIZATION

### 5.1 โมเดลที่แนะนำ (เหมาะกับ cozy idle)
**Hybrid ที่เน้นความเป็นมิตร ไม่ pay-to-win:**
1. **Gacha ใจดี (แกนหลัก):** สุ่มตัวละคร/costume — อัตราดรอปสูงพอควร, pity system โปร่งใส, เปิดเผยอัตรา (เรียนจาก CRK: rarity สมดุลกับ drop rate + non-payer สะสมได้)
2. **Battle Pass ตามฤดูกาล:** track ฟรี + premium ให้ cosmetics/สกุลเงิน คุ้มค่า ไม่ grind หนัก (ต้นทุนต่ำ ผูก daily/weekly quest — เรียนจาก AFK Arena)
3. **Cosmetics/Costume shop:** แกน self-expression — ปลอกคอ, หมวก, สีขน, เอฟเฟกต์ (fairest monetization)
4. **Subscription/Monthly pass:** โบนัสสกุลเงินรายวัน + QoL (เช่น auto-features, offline cap +)
5. **Rewarded ads (optional, เป็นมิตร):** ดูโฆษณาที่ "แมวเอามาเสนอ" เพื่อ speed-up/free pull (echo Neko Atsume guilt-free ads) — ไม่บังคับ ไม่ขัดจังหวะ

### 5.2 หลักจริยธรรม/เป็นมิตรกับผู้เล่น
- **เปิดเผยอัตรา gacha** (จำเป็นตามกฎหมายบางประเทศ เช่น เบลเยียม/เนเธอร์แลนด์แบน loot box) + pity รับประกันหลังจำนวนสุ่มที่กำหนด
- **ไม่มี pay-to-win แข็ง:** การจ่ายเงินเร่งความเร็ว/ให้ประโยชน์ทางอ้อม (echo AFK VIP) ไม่ใช่ซื้อชัยชนะตรง
- **เลี่ยง dark pattern:** ไม่มี timer หลอก, ไม่มี subscription ยกเลิกยาก, ไม่ยิง pop-up ถี่ (echo CRK: ไม่ใช้ pop-up รกแบบเกมมือถือทั่วไป)
- **F2P จบเนื้อหาได้:** เคลียร์เกมได้โดยไม่ต้องจ่าย (echo TBH: "not pay-to-win, clearable without spending")
- **เก็บเงินจากคอร์แฟนที่ภักดี ไม่ใช่บีบผู้เล่นใหม่:** ร้านค้าช่วงต้นเกมควรเรียบง่าย เสนอ pack คุ้ม ๆ เมื่อผู้เล่นเข้าใจเกมแล้ว (เรียนจากบทวิเคราะห์ CRK ที่แนะนำให้เลี่ยง analysis paralysis ในช่วงต้นเกม)

### 5.3 อ้างอิงการเก็บเงินของเกมใกล้เคียง
- **CRK:** gacha + battle pass + costume + value pack, ทำรายได้ "ราวหนึ่งในสี่พันล้านดอลลาร์จากยอดดาวน์โหลด 22 ล้าน" (≈ >$10/ดาวน์โหลด), ไม่มีโฆษณา, เก็บจากคอร์แฟน
- **FGO:** gacha Saint Quartz เป็นหลัก (รายได้สูงมากจาก banner limited — ทำรายได้กว่า $55 ล้านในเดือนสิงหาคม 2025 เดือนเดียว ตามข้อมูลที่อ้างโดย Nikke.gg)
- **AFK Arena:** ไม่ขาย progression ตรง, VIP + battle pass, ให้ของฟรีเยอะช่วงต้น
- **Neko Atsume:** ads เป็นมิตร + ซื้อสกุลเงิน, guilt-free (ยอดดาวน์โหลดกว่า 33 ล้านทั้งซีรีส์)
- **แนวทางเรา:** โน้มไป CRK + Neko Atsume (ใจดี, cozy, cosmetics-first) มากกว่า FGO (gacha หนัก)

---

## Recommendations (ข้อเสนอเชิงปฏิบัติแบบเป็นขั้น)

**Phase 1 — Prototype (0-3 เดือน):** สร้าง core loop ปาร์ตี้ 4 แมว auto-battle + 1 ภูมิภาค (Emberhearth) + 6 ตระกูลตัวอย่างละ 1 ตัว โฟกัส "feel" ของการสู้และ reward cadence + prototype เสียง (tight SFX + purr ambient). **Benchmark:** เซสชัน 5 นาทีต้องรู้สึก "อยากเล่นต่ออีกรอบ"

**Phase 2 — Vertical Slice (3-6 เดือน):** เพิ่ม gacha ใจดี + pity, equipment + cosmetics, offline progression + AFK chest, adaptive music layering. **Benchmark:** Day-1 retention >40%, Day-7 >20% ในการทดสอบ soft launch

**Phase 3 — Soft Launch (6-10 เดือน):** เปิด 3 ภูมิภาค, battle pass, daily/weekly, guild. **Benchmark:** DAU/MAU >30% (เทียบ CRK), ARPPU สุขภาพดี, ไม่มีเสียงบ่นเรื่อง monetization

**Threshold ที่จะเปลี่ยนแผน:**
- ถ้า Day-2 retention <20% → รื้อ core loop/reward cadence (สัญญาณ front-load หรือ loop น่าเบื่อ — 80% ของเกม idle ตายที่นี่)
- ถ้าเจอกำแพง progression ที่ผู้เล่นบ่น → ปรับ scaling ให้ไม่ชันเกิน (บทเรียน TBH Lv.65 wall)
- ถ้ารีวิว monetization เป็นลบ → เพิ่มความใจดี gacha/ลด pop-up

**ลำดับความสำคัญการลงทุน:** (1) Sound design + cuteness (เสาหลัก อย่าลดคุณภาพ) (2) core loop feel (3) gacha/retention systems (4) content breadth

---

## Caveats (ข้อควรระวัง)
- **ข้อมูล TBH: Task Bar Hero** ส่วนใหญ่มาจาก wiki/บล็อกไม่เป็นทางการและเว็บขาย mod (xmodhub) — ตัวเลข concurrent players (peak 364,058 วันที่ 6 มิ.ย. 2026) และ Mixed rating (43-45% positive) ควรตรวจสอบกับ SteamDB/Steam โดยตรงก่อนอ้างอิงจริง
- **ตัวเลข monetization ของ CRK** (รายได้ราว $225M จาก 22M ดาวน์โหลด ≈ >$10/ดาวน์โหลด, DAU/MAU >30%) มาจากบทวิเคราะห์บุคคลที่สาม (Udonis, Deconstructor of Fun) เป็นการประมาณการ ไม่ใช่ตัวเลขทางการจาก Devsisters; เอกสาร lore ภายในชื่อ "Compendium of the Cookie World" ราว 300 หน้า (ตาม Devsisters) ขณะที่ art collection ฉบับตีพิมพ์ขายคือ 200 หน้า (ตาม Deconstructor of Fun) — เป็นคนละเอกสารกัน
- **การแม็ปสายพันธุ์แมว→บุคลิก** อิงลักษณะทั่วไปของสายพันธุ์ (เชิง stereotype เพื่อการออกแบบ) ไม่ใช่ข้อเท็จจริงทางสัตววิทยาที่ตายตัว
- **World-building "Purralia" ทั้งหมดเป็นข้อเสนอต้นฉบับ** ที่สร้างขึ้นใหม่สำหรับโปรเจกต์นี้ ควรตรวจสอบเรื่องเครื่องหมายการค้า/ความซ้ำกับ IP อื่นก่อนใช้จริง (โดยเฉพาะ motif "ด้าย/ทอโลก" และชื่อเฉพาะ)
- **งานวิจัยเสียง "juicy audio"** (ACM 2024, Springer 2021) เป็นงาน peer-reviewed ที่น่าเชื่อถือ แต่ claim เรื่อง "เสียง reward เพิ่ม serotonin" จากบล็อกอุตสาหกรรมยังไม่มีงานวิจัยตรงรองรับ — ใช้อย่างระมัดระวัง
- **โมเดล gacha** เผชิญการกำกับดูแลที่เข้มขึ้นเรื่อย ๆ ทั่วโลก ควรออกแบบให้ยืดหยุ่นต่อกฎหมายแต่ละภูมิภาค

---

*เอกสารนี้เป็นรากฐาน (foundation) สำหรับทีมพัฒนา — โครงเรื่อง โลก และระบบทั้งหมดออกแบบให้ต่อยอด/ปรับแก้ได้ในขั้น pre-production ถัดไป*
