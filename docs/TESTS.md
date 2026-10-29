# Checks run on 29 October 2026

These checks were run on the Debug build of Timeline Studio, on the chronology already open on this Mac: **Closing the Northwind Deal**, 21 events, horizontal layout, lanes named Emails, Text Messages, and Meetings. After each check the store still had those 21 events and that title. The Release disk image was built from the same source after the app had quit.

## What passed

- The app launched to that chronology. The sidebar counted 21 events. The three lane names were Emails, Text Messages, and Meetings.
- File → New Event… showed the type, the timeline, the date, all-day, the location, and the notes. Escape closed the sheet and left the chronology unchanged.
- Adding an event titled “QA marker event” raised the count to 22. Edit → Undo returned the count to 21. The title of the chronology stayed “Closing the Northwind Deal.”
- Switching to the vertical layout and back to horizontal left the count at 21 and left the title unchanged.
- Timeline → AI… opened one text field. The sheet says to type a change and press Return, and that the API key stays in the keychain. On this Mac the model line read “xAI · grok-4.5 · key saved.” More lists Extract from a Document…, Review the Timeline, and Write a Memo. Escape closed the sheet. No request was sent, so the chronology was not edited.
- Presentation opened on the title card. The right arrow advanced to event 1 of 21, “Draft term sheet from Dana,” with the category list in the sidebar (Text Message 9, Email 7, Meeting 5).

## Import

File → Import CSV… opened a preview titled Import Preview for `SampleData/henderson-v-acme.csv` (the six-row fictional Henderson v. Acme file). A Return that was still queued from the file dialog pressed the preview’s default button, **Import 6 Events**, and the chronology grew from 21 events to 27. The six Henderson titles were present. The store was then restored from the backup taken before the tests. A clean cancel of that preview was not completed. Do not press Return while the preview is open unless you mean to import.

## Not run against the open chronology

The confirmation banner, and the link from that banner into the event editor, were not exercised. That path applies the model’s edit immediately and would have added another event to this chronology. The sheet itself, and the copy that describes the link, were checked. Undo of an ordinary new event was checked.

## After the checks

The app was quit. The store on disk still had 21 events, the title “Closing the Northwind Deal,” and the horizontal layout. The Release app was then built. A scan compared the app bundle with the API key stored on this Mac and printed only whether those bytes were present. They were not. The Debug loader that reads `XAI_API_KEY` from the environment was not in the Release binary. The disk image is that Release app, ad-hoc signed, for both Apple silicon and Intel.
