import Foundation

/// One SF Symbol a category icon can use. Keywords drive the name matcher.
struct CategorySymbol: Identifiable, Hashable, Sendable {
    let name: String
    let keywords: [String]
    var id: String { name }
}

/// A labeled set of symbols in the category icon browser.
struct CategorySymbolGroup: Identifiable, Sendable {
    let title: String
    let symbols: [CategorySymbol]
    var id: String { title }
}

/// Symbols that render inside the same rounded tile as the built-in categories.
///
/// Every name here shipped with SF Symbols 5 or earlier, so it exists on macOS 14.
/// Matching is local word overlap. Nothing is generated or fetched.
enum CategorySymbolLibrary {
    static let groups: [CategorySymbolGroup] = [
        group("Communication", [
            ("message.fill", "text message sms chat imessage"),
            ("recordingtape", "recorded jail 911"),
            ("phone.fill", "phone call telephone"),
            ("phone.badge.waveform.fill", "voicemail call"),
            ("phone.arrow.up.right.fill", "outgoing call"),
            ("phone.arrow.down.left.fill", "incoming call"),
            ("envelope.fill", "email mail letter post"),
            ("envelope.open.fill", "opened letter read mail"),
            ("video.fill", "video recording filmed"),
            ("mic.fill", "microphone audio interview voice recording"),
            ("mic.slash.fill", "silent muted noaudio"),
            ("bubble.left.and.bubble.right.fill", "conversation dialogue talk discussion"),
            ("ellipsis.bubble.fill", "comment remark aside"),
            ("paperplane.fill", "send sent delivered dispatch"),
            ("megaphone.fill", "announcement speech press statement broadcast"),
            ("antenna.radiowaves.left.and.right", "radio signal wireless transmission"),
            ("quote.bubble.fill", "quote statement testimony said"),
            ("waveform", "audio sound recording waveform"),
            ("exclamationmark.bubble.fill", "threat urgent message"),
            ("iphone", "phone cellphone seized handset mobile"),
            ("iphone.radiowaves.left.and.right", "cellsite ping cellular cell"),
        ]),
        group("People", [
            ("person.fill", "person individual client witness someone"),
            ("person.2.fill", "meeting people pair couple two"),
            ("person.3.fill", "group family team crowd"),
            ("person.crop.circle.fill", "profile portrait contact"),
            ("person.fill.checkmark", "identified confirmed person"),
            ("figure.walk", "walk walking pedestrian"),
            ("figure.run", "run running jog chase"),
            ("hand.raised.fill", "oath swear hand raised stop"),
            ("hand.wave.fill", "greeting hello wave welcome"),
            ("person.badge.shield.checkmark.fill", "officer deputy trooper sworn"),
            ("person.fill.questionmark", "unidentified suspect doe"),
            ("person.3.sequence.fill", "lineup jury venire photoarray"),
            ("person.fill.xmark", "deceased death unavailable witness"),
            ("person.crop.circle.badge.checkmark", "identification"),
            ("person.crop.circle.badge.xmark", "alibi"),
            ("person.crop.circle.badge.exclamationmark", "complainant poi"),
            ("person.crop.rectangle.stack.fill", "photoseries series mugshot"),
            ("person.line.dotted.person.fill", "codefendant coconspirator defendant conspirator"),
            ("lanyardcard.fill", "lanyard credentials credential idcard id"),
            ("hand.raised.slash.fill", "invoked refusal declined refused oath"),
            ("figure.and.child.holdinghands", "minor custody parent child"),
            ("figure.fall", "fall fallen downed"),
            ("figure.seated.seatbelt", "occupant seatbelt passenger"),
        ]),
        group("Places", [
            ("house.fill", "home house residence"),
            ("building.2.fill", "office building company workplace"),
            ("building.columns.fill", "court courthouse capitol government museum hearing"),
            ("mappin.and.ellipse", "location place pin visit site outing"),
            ("map.fill", "map route"),
            ("bed.double.fill", "hotel sleep lodging stay bedroom"),
            ("tent.fill", "camp camping outdoors"),
            ("signpost.right.fill", "direction sign route"),
            ("sofa.fill", "couch living room lounge"),
            ("door.left.hand.open", "entry entered"),
            ("door.garage.open", "garage burglary"),
        ]),
        group("Travel", [
            ("airplane", "flight airplane airport travel plane trip"),
            ("airplane.departure", "departure takeoff leaving"),
            ("airplane.arrival", "arrival landing arriving"),
            ("car.fill", "car drive driving vehicle auto"),
            ("steeringwheel", "driver steering"),
            ("road.lanes", "roadway lanes road"),
            ("car.2.fill", "vehicles multivehicle"),
            ("box.truck.fill", "truck commercial"),
            ("bus.fill", "bus transit coach"),
            ("tram.fill", "train rail subway metro tram"),
            ("ferry.fill", "boat ship ferry cruise"),
            ("bicycle", "bike bicycle cycling"),
            ("fuelpump.fill", "fuel gas station"),
        ]),
        group("Time", [
            ("calendar.badge.exclamationmark", "limitations speedy deadline sol"),
            ("calendar.badge.clock", "trial trialdate hearingdate"),
            ("clock.badge.checkmark.fill", "timely ontime filed"),
            ("clock.badge.xmark.fill", "continuance missed expired late"),
            ("hourglass.bottomhalf.filled", "advisement pendingruling"),
            ("arrow.uturn.backward", "appeal remand reconsideration"),
            ("clock.fill", "time clock hour"),
            ("calendar", "date day schedule calendar"),
            ("alarm.fill", "alarm reminder alert"),
            ("hourglass", "wait waiting delay pending"),
            ("timer", "timer duration stopwatch"),
            ("sun.max.fill", "day morning daylight sun"),
            ("moon.fill", "night evening moon"),
            ("sunrise.fill", "sunrise dawn"),
            ("sunset.fill", "sunset dusk"),
            ("clock.arrow.circlepath", "history past recurring repeat"),
        ]),
        group("Work", [
            ("briefcase.fill", "work job business office"),
            ("scanner.fill", "scan scanned scanner"),
            ("doc.text.fill", "document file report paper contract record"),
            ("doc.richtext.fill", "letter brief writing"),
            ("folder.fill", "folder files records"),
            ("paperclip", "attachment clip enclosed"),
            ("signature", "signature signed sign"),
            ("pencil", "write edit draft"),
            ("tray.full.fill", "inbox received"),
            ("archivebox.fill", "archive storage boxed"),
            ("printer.fill", "print printed copy"),
            ("scissors", "cut trim"),
            ("doc.on.doc.fill", "copy duplicate"),
            ("doc.text.magnifyingglass", "search review investigation research"),
            ("list.clipboard.fill", "list agenda clipboard"),
            ("note.text", "note memo"),
            ("doc.plaintext.fill", "complaint indictment charging information"),
            ("doc.append.fill", "amended amendment supplemental"),
            ("square.and.pencil", "motion pleading"),
            ("doc.on.clipboard.fill", "subpoena served service"),
            ("list.bullet.clipboard.fill", "discovery interrogatory interrogatories production"),
            ("checklist", "checklist brady giglio"),
            ("text.book.closed.fill", "statute code ordinance penal"),
            ("books.vertical.fill", "authorities caselaw reporter"),
            ("scroll.fill", "order judgment decree"),
            ("paragraphsign", "citation cite section"),
            ("text.quote", "transcript excerpt colloquy"),
            ("highlighter", "exhibit highlight marked"),
            ("text.redaction", "redaction redacted privilege"),
            ("shippingbox.fill", "package parcel"),
        ]),
        group("Money", [
            ("cart.fill", "purchase buy shopping store cart"),
            ("creditcard.trianglebadge.exclamationmark", "fraud fraudulent chargeback disputed dispute"),
            ("creditcard.fill", "card payment credit charge"),
            ("banknote.fill", "cash money bill payment"),
            ("dollarsign.arrow.circlepath", "restitution refund transfer"),
            ("dollarsign.circle.fill", "price cost fee dollar amount"),
            ("bag.fill", "shopping bag"),
            ("tag.fill", "tag sale price label"),
            ("gift.fill", "gift present"),
            ("chart.bar.doc.horizontal", "damages damage worksheet"),
            ("chart.pie.fill", "settlement comparative fault"),
            ("chart.line.downtrend.xyaxis", "loss depreciation"),
            ("percent", "interest percentage percent"),
        ]),
        group("Health", [
            ("cross.case.fill", "medical hospital doctor clinic health emergency"),
            ("cross.vial.fill", "toxicology blood vial tox"),
            ("stethoscope", "doctor physician exam checkup"),
            ("pills.fill", "medicine medication prescription pharmacy pills"),
            ("bandage.fill", "injury wound bandage"),
            ("cross.fill", "aid first medical"),
            ("heart.fill", "heart health cardiac"),
            ("staroflife.fill", "ambulance ems emergency"),
            ("syringe.fill", "injection shot vaccine"),
            ("brain.head.profile", "mental mind therapy psychology"),
            ("lungs.fill", "breath breathing respiratory"),
            ("waveform.path.ecg", "pulse ecg heartbeat"),
            ("eye.fill", "eye sight saw seen vision"),
            ("ear.fill", "ear listen sound"),
        ]),
        group("Legal", [
            ("scalemass.fill", "law legal justice scale balance trial"),
            ("hammer.fill", "judge ruling decision gavel"),
            ("shield.fill", "police protect safety security badge arrest"),
            ("lock.fill", "lock locked secure confidential"),
            ("key.fill", "key access"),
            ("lock.shield.fill", "security protected"),
            ("checkmark.seal.fill", "certified official approved verified"),
            ("seal.fill", "seal stamp official"),
            ("flag.fill", "flag marker milestone"),
            ("exclamationmark.triangle.fill", "warning caution incident"),
            ("exclamationmark.octagon.fill", "stop violation prohibited"),
            ("eye.slash.fill", "hidden secret private"),
            ("touchid", "fingerprint latent"),
            ("lock.doc.fill", "sealed privileged underseal"),
            ("flag.checkered", "verdict sentencing disposition"),
            ("exclamationmark.shield.fill", "alert security"),
            ("binoculars.fill", "watch observe surveillance lookout"),
            ("lock.open.fill", "unsealed waived waiver"),
            ("envelope.badge.shield.half.filled.fill", "correspondence privilegedmail privileged mail"),
            ("checkmark.shield.fill", "granted protective order protection"),
            ("xmark.shield.fill", "denied denial"),
            ("nosign", "excluded exclude limine inadmissible"),
            ("xmark.octagon.fill", "suppressed suppression suppress"),
            ("checkmark.rectangle.portrait.fill", "admitted admission admit admissible"),
            ("faceid", "facial recognition face"),
            ("person.fill.viewfinder", "showup incourt eyewitness"),
        ]),
        group("Media", [
            ("camera.fill", "camera photo photograph picture evidence"),
            ("web.camera.fill", "cctv closedcircuit"),
            ("video.doorbell.fill", "doorbell ringcamera"),
            ("video.slash.fill", "cameraoff inactive missingvideo missing video off"),
            ("photo.fill", "photo image picture"),
            ("photo.stack.fill", "photoset scenephotos scene"),
            ("lock.iphone", "passcode lockeddevice device"),
            ("laptopcomputer", "laptop computer search"),
            ("externaldrive.fill", "drive imaged forensic"),
            ("simcard.fill", "sim simcard card"),
            ("sdcard.fill", "sdcard memorycard memory card sd"),
            ("airtag", "tracker tracking airtag"),
            ("barcode.viewfinder", "barcode propertytag property tag"),
            ("film.fill", "film movie cinema"),
            ("music.note", "music song concert"),
            ("headphones", "headphones podcast listen"),
            ("tv.fill", "television tv broadcast show"),
            ("book.fill", "book reading"),
            ("book.closed.fill", "textbook book"),
            ("newspaper.fill", "news press article newspaper headline"),
            ("graduationcap.fill", "school college university class education student"),
            ("theatermasks.fill", "theater performance play acting"),
            ("ticket.fill", "ticket admission event show"),
            ("guitars.fill", "guitar band music"),
            ("pianokeys", "piano music"),
        ]),
        group("Home", [
            ("fork.knife", "meal food dinner lunch restaurant dining"),
            ("cup.and.saucer.fill", "coffee tea cafe"),
            ("wineglass.fill", "drink reception bar wine"),
            ("birthday.cake.fill", "birthday party cake celebration"),
            ("lightbulb.fill", "idea thought"),
            ("wrench.and.screwdriver.fill", "repair tool fix maintenance"),
            ("paintbrush.fill", "art paint design draw"),
            ("gamecontroller.fill", "game play gaming"),
            ("sportscourt.fill", "sport match field"),
            ("football.fill", "football sports ball"),
            ("dumbbell.fill", "gym workout exercise fitness"),
            ("pawprint.fill", "pet dog cat animal"),
            ("tshirt.fill", "clothes clothing uniform"),
            ("bell.fill", "notification notice bell"),
            ("trophy.fill", "trophy win award champion"),
            ("medal.fill", "medal award honor"),
            ("rosette", "award prize ribbon"),
        ]),
        group("Nature", [
            ("leaf.fill", "plant garden nature leaf"),
            ("drop.fill", "water drop liquid"),
            ("flame.fill", "fire flame"),
            ("snowflake", "snow winter cold"),
            ("cloud.rain.fill", "weather rain storm"),
            ("bolt.fill", "power electric lightning"),
            ("globe.americas.fill", "world globe international earth"),
            ("atom", "science research physics"),
            ("testtube.2", "lab laboratory sample test science"),
        ]),
        group("Marks", [
            ("star.fill", "star favorite important"),
            ("bookmark.fill", "bookmark saved"),
            ("pin.fill", "pin pinned"),
            ("link", "link url web"),
            ("target", "target goal aim"),
            ("info.circle.fill", "information info about"),
            ("questionmark.circle.fill", "question unknown ask"),
            ("checkmark.circle.fill", "done complete yes finished"),
            ("xmark.circle.fill", "cancel no closed"),
            ("plus.circle.fill", "new add create"),
            ("number", "number count"),
            ("diamond.fill", "gem diamond valuable"),
        ]),
    ]

    static let all: [CategorySymbol] = groups.flatMap(\.symbols)

    /// Best symbols for a category name. Highest score first. Empty when nothing overlaps.
    static func suggestions(matching raw: String, limit: Int = 8) -> [CategorySymbol] {
        let tokens = tokens(from: raw)
        guard !tokens.isEmpty else { return [] }
        return all
            .map { ($0, score($0, tokens: tokens)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Groups for the browser. An empty query returns the whole library.
    static func groups(matching raw: String) -> [CategorySymbolGroup] {
        let tokens = tokens(from: raw)
        guard !tokens.isEmpty else { return groups }
        return groups.compactMap { group in
            let symbols = group.symbols.filter { score($0, tokens: tokens) > 0 }
            guard !symbols.isEmpty else { return nil }
            return CategorySymbolGroup(title: group.title, symbols: symbols)
        }
    }

    private static let ignored: Set<String> = [
        "a", "an", "the", "of", "and", "or", "to", "for", "in", "on", "at", "with",
    ]

    private static func tokens(from raw: String) -> [String] {
        raw.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 && !ignored.contains($0) }
    }

    private static func score(_ symbol: CategorySymbol, tokens: [String]) -> Int {
        let nameParts = symbol.name.split(separator: ".").map { part in
            String(part).filter(\.isLetter)
        }.filter { $0.count >= 2 }
        return tokens.reduce(0) { partial, token in
            let keywordScore = symbol.keywords.map { matchScore(token, $0) }.max() ?? 0
            let nameScore = nameParts.map { max(0, matchScore(token, $0) - 1) }.max() ?? 0
            return partial + max(keywordScore, nameScore)
        }
    }

    /// Exact words score highest. A shorter word can match a longer one when it is long enough not to be an accident.
    private static func matchScore(_ token: String, _ keyword: String) -> Int {
        if token == keyword { return token.count >= 3 ? 10 : 6 }
        guard token.count >= 3, keyword.count >= 3 else { return 0 }
        if keyword.hasPrefix(token) || token.hasPrefix(keyword) {
            let shortest = min(keyword.count, token.count)
            let difference = abs(keyword.count - token.count)
            if shortest >= 4 && (difference <= 2 || shortest >= 5) { return 6 }
        }
        // "flights" still matches "flight". A match buried inside another word does not.
        if token.count > keyword.count, token.hasPrefix(keyword), keyword.count >= 4 { return 4 }
        return 0
    }

    private static func group(_ title: String, _ rows: [(String, String)]) -> CategorySymbolGroup {
        CategorySymbolGroup(
            title: title,
            symbols: rows.map { name, words in
                CategorySymbol(name: name, keywords: words.split(separator: " ").map(String.init))
            }
        )
    }
}
