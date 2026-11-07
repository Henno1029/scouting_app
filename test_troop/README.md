# Test Troop

A made-up troop for trying every part of the app. **Everyone here is fictional**: the member IDs, phone numbers (555-01xx) and `example.com` emails aren't real.

## Keep it away from your real data

The app stores imports in the browser, and these files merge with whatever is already there. There's no delete-all for scouts. Use a separate port, which gets its own separate storage:

```
flutter run -d chrome --web-port 8081
```

## Load it

Go to **Upload Data**, pick the report type, choose the file, and press Import. Do them in this order:

| Report type | File | What it tests |
|---|---|---|
| Roster | `roster.csv` | Creates 14 scouts with patrols and member IDs |
| Advancements | `advancements.csv` | Records and ranks, and creates a 15th scout, Owen Brooks |
| Activities | `activities.csv` | Stores the activity log (no screen shows it yet) |
| Program Grid | `program_grid.csv` | November 2026 to April 2027 calendar with every event type |

Then open **Branding & Patrols** to set a troop name, such as `Troop 9999`, so it shows on the printouts.

## The scouts

| Scout | Roster rank | Patrol | What this one tests |
|---|---|---|---|
| Ethan Walker | None | Fox | Brand new: no rank and no records |
| Liam Ortiz | Scout | Fox | Scout rank, partway through Tenderfoot |
| Maya Patel | Scout | Fox | Scout rank, nearly done with Tenderfoot, a middle name |
| Noah Kim | Tenderfoot | Hawk | Tenderfoot with a first merit badge |
| Mateo Núñez | Tenderfoot | Hawk | Accented name, and one record with no requirement number |
| Ava Thompson | Second Class | Hawk | Second Class, early in First Class |
| Sofia Bennett | Second Class | Wolf | Second Class, nearly First Class |
| Lucas Greene | First Class | Wolf | First Class, Star service hours open |
| Isabella Chen | First Class | Wolf | First Class with many merit badges |
| Oliver Hayes | Star | Raven | Star, Life service hours open |
| Charlotte Rivera | Life | Raven | Life, nothing left to complete at events |
| Henry Vance | Eagle | Raven | Eagle, every section empty |
| Jon Reed | Tenderfoot | None | No patrol. Name is contained in Jon Reedy, showing the known name-matching bug |
| Jon Reedy | Scout | Fox | Name contains Jon Reed, showing the known name-matching bug |
| Owen Brooks | Scout (from import) | None | Not on the roster, created by the advancement import |

The roster also lists position, birth date, phone, email and parent details. The app doesn't store these yet, but they're there for filling in the Scout Planning Worksheet.

Requirement records with a blank completion date count as not done, so those requirements should still be listed.

## Things to try

**Calculation Page, Event Calculations**
- Choose a meeting and tick everyone. Ethan should have the longest list, and Charlotte and Henry should have nothing left.
- Choose **Wreaths for Veterans**. Lucas and Isabella should get `Star 4`, and Oliver should get `Life 4`.
- Choose **Fall Court of Honor** to see the message that no requirements are tied to that type. A Court of Honor has none.
- Mateo should show a note that one record couldn't be matched to a requirement number.
- Tick a few scouts and press the print button.

**Calculation Page, Event Plans**
- **Winter Camp at Test Lake** should appear once as `12/11 to 12/13/2026`. Fill it out, press Save, then tap each of those days on the calendar.
- Choose a meeting, press **Add item**, type `instruction`, and press Enter. With Ollama running, it should go into Group Instruction with an Undo.
- Type `order pizza` the same way to try Undo if the model guesses wrong.
- Enter a start time like `7:00 PM`, then press **Fill out Meeting Plan**.
- On a campout, press **Fill out Scout Planning Worksheet**.
- Enter a very long answer in a form field to see it carried to the attached page.

**Everything else**
- **Scout Page:** open a scout to see ranks, merit badges and requirement progress. Edit a patrol or clear one.
- **Event Page:** try month and year views, the type filter, editing, deleting, and the year PDF.
- **Upload Data:** import `advancements.csv` a second time. It should add 0 new records.

## Known problems this troop will show

- **Jon Reed and Jon Reedy share records.** Names are matched loosely, so one name contained in another counts as the same scout. Jon Reed will appear to have Jon Reedy's Tenderfoot records.
- **Renaming a scout** disconnects their advancement records, because records are matched by name.
- **The Advancement Record (IAR) import isn't connected** to its parser, so no sample is included for it.
- **A plain date, title and type file won't import as a Program Calendar.** Use the grid file above.
