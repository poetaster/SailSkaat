import QtQuick 2.6
import Sailfish.Silica 1.0

import "../js/skaat.js" as Skaat
import "../cards"
import "../cards/cards.js" as Cards
import "../components"


Page {
    id: page

    allowedOrientations: Orientation.Portrait

    // The engine, and mirrors of its state for QML bindings.
    property var engine: null
    property var bots: [null, null, null]
    property string step: ""
    property var actor: null
    property var hand: []
    property var hands: [[], [], []]
    property var skat: []
    property var trick: []
    property var tricks: []
    property var result: null
    property var declaredGame: null
    property int declarer: -1
    property var matchScore: [0, 0, 0]

    // Choices in progress.
    property var selected: []
    property bool schneider: false
    property bool schwarz: false
    property bool ouvert: false
    property string errorText: ""
    property string lastGameText: ""

    // Trick display. In-progress tricks are shown as they form, but the
    // engine clears a trick the moment its third card is played, so the
    // finished trick would never be seen. We hold the completed trick
    // (engine.state.lastTrick) on the table for a short settle period so
    // all three cards are actually visible before the next trick starts.
    property var lastTrick: null
    property string lastTrickKey: ""
    property bool settling: false
    readonly property var displayTrick: page.trick.length > 0
        ? page.trick
        : (page.settling ? (page.lastTrick || []) : [])

    // Where every card sits (in root coordinates); see computePlaces().
    readonly property var places: computePlaces()

    // Table sizing.
    readonly property real margin: Theme.horizontalPageMargin
    readonly property real pad: Theme.paddingMedium
    // Sizing is for a full 10-card hand from the start, so the cards never
    // change size mid-game (and the pack has its real size on first load).
    property int maxHand: 10
    readonly property real spread: 0.5
    readonly property real cardWidth: Math.floor(
        (page.width - 2 * page.margin) / (1 + (Math.max(1, page.maxHand) - 1) * page.spread))
    readonly property real cardHeight: Math.round(page.cardWidth * 1.42)
    readonly property real botCardW: Math.round(page.cardWidth * 0.7)
    readonly property real botCardH: Math.round(page.botCardW * 1.42)
    readonly property real botFanW: page.botCardW * (1 + 9 * 0.32)

    readonly property bool finished: page.step === "end"
    readonly property bool allPass: page.step === "ask-declare" && page.actor === null
    readonly property bool playing: page.declaredGame !== null

    // Skat is laid face up once someone has declared;
    readonly property bool skatRevealed: page.declaredGame !== null

    function playerName(p) {
        if (p === 0)
            return qsTr("You")
        if (p === 1)
            return qsTr("Bot 1")
        if (p === 2)
            return qsTr("Bot 2")
        return ""
    }

    function suitText(suit) {
        if (suit === Skaat.Constants.Grand)
            return qsTr("Grand")
        if (suit === Skaat.Constants.Null)
            return qsTr("Null")
        if (suit === Skaat.Constants.Ramsch)
            return qsTr("Ramsch")
        return String(suit)
    }

    // Declared-game suffix for the score labels, e.g. "· ♥ Hand +3 jacks"
    // for the declarer and "· defender" for the other two. Empty before a
    // game has been declared.
    function scoreSuffix(player) {
        if (!page.declaredGame)
            return ""
        if (page.declarer === player)
            return "  ·  " + page.gameText()
        return "  ·  " + qsTr("defender")
    }

    function gameText() {
        if (!page.declaredGame)
            return ""
        var text = page.suitText(page.declaredGame.suit)
        var m = page.declaredGame.modifiers || 0
        if (m & Skaat.Constants.Hand)
            text += " " + qsTr("Hand")
        if (m & Skaat.Constants.Overt)
            text += " " + qsTr("Ouvert")
        if (m & Skaat.Constants.Schwarz)
            text += " " + qsTr("Schwarz")
        else if (m & Skaat.Constants.Schneider)
            text += " " + qsTr("Schneider")
        if (m & Skaat.Constants.Contra)
            text += " " + qsTr("Contra")
        if (page.declaredGame.jacks)
            text += " +" + page.declaredGame.jacks + qsTr(" jacks")
        return text
    }

    function statusText() {
        if (page.errorText)
            return page.errorText
        if (page.finished)
            return page.lastGameText
        if (page.allPass)
            return qsTr("Nobody declared — no points were scored.")
        var who = page.actor === 0
            ? qsTr("You ")
            : (page.actor === null ? "" : page.playerName(page.actor) + " ")
        if (page.step === "ask-bid") {
            var cb = page.currentBidInfo()
            if (page.actor === 0) {
                if (cb)
                    return qsTr("Current bid ") + cb + ". " + qsTr("Pass or bid higher.")
                return qsTr("Nobody has bid yet — open the bidding at 18, or pass.")
            }
            return who + qsTr("is weighing the cards") + (cb ? " (" + cb + ")" : "") + "…"
        }
        if (page.step === "ask-ack")
            return who + (page.actor === 0 ? qsTr("may contra or pass.") : qsTr("thinks about a contra…"))
        if (page.step === "ask-declare")
            return who + (page.actor === 0
                ? qsTr("declares: name a game, or take the skat first.")
                : qsTr("decides which game to play…"))
        if (page.step === "ask-skat")
            return who + (page.actor === 0 ? qsTr("drop two cards into the skat, then declare the game.") : qsTr("picks two cards to drop…"))
        if (page.step === "ask-card")
            return who + (page.actor === 0 ? qsTr("tap a card to play.") : qsTr("is choosing a card…"))
        return ""
    }

    // Human-readable current bid, e.g. "20 by Bot 1" ("" if nobody has bid yet).
    function currentBidInfo() {
        var b = (page.engine && page.engine.state.bidding) ? page.engine.state.bidding : null
        if (!b || !b.bid)
            return ""
        var s = String(b.bid)
        if (b.leader != null)
            s += " " + qsTr("by ") + page.playerName(b.leader)
        return s
    }

    // Prominent current-bid indicator; shown only once a bot has actually bid.
    function bidChipText() {
        var b = (page.engine && page.engine.state.bidding) ? page.engine.state.bidding : null
        if (!b || !b.bid)
            return ""
        var who = (b.leader != null) ? "  " + page.playerName(b.leader) : ""
        return qsTr("Current bid ") + b.bid + who
    }

    // Bids allowed now: everything above the current bid.
    readonly property var bidList: {
        var bid = (page.engine && page.engine.state.bidding) ? page.engine.state.bidding.bid : null
        var out = []
        for (var i = 0; i < Skaat.BIDS.length; ++i)
            if (Skaat.BIDS[i] > (bid || 0))
                out.push(Skaat.BIDS[i])
        return out
    }

    // Engine functions

    function newGame() {
        page.selected = []
        page.schneider = false
        page.schwarz = false
        page.ouvert = false
        page.errorText = ""
        page.result = null
        page.trick = []
        page.maxHand = 1
        page.lastTrick = null
        page.lastTrickKey = ""
        page.settling = false
        settleTimer.stop()
        page.declaredGame = null
        page.declarer = -1
        page.lastGameText = ""
        page.matchScore = [0, 0, 0]
        page.bots = [null, new Skaat.Automa(), new Skaat.Automa()]
        page.engine = new Skaat.Game()
        page.advance("start")
    }

    function advance(step, player, arg1, arg2) {
        var args = [step]
        if (player !== undefined)
            args.push(player)
        if (arg1 !== undefined)
            args.push(arg1)
        if (arg2 !== undefined)
            args.push(arg2)
        var res
        try {
            res = page.engine.next.apply(page.engine, args)
        } catch (err) {
            console.log("skaat advance THREW on " + step + ": " + String(err && err.message || err))
            page.errorText = qsTr("The engine said: %1").arg(String(err && err.message || err))
            return
        }
        console.log("skaat advance " + step + " -> state=" + String(res[0]) + " actor=" + res[1])
        page.errorText = ""
        var wasFinished = page.finished
        page.step = String(res[0])
        page.actor = (res.length > 1 && res[1] !== undefined && res[1] !== null) ? res[1] : null
        page.refresh()
        if (!wasFinished && page.finished && page.result)
            page.scoreGame()
        page.scheduleBots()
    }

    // keep track of the trick TO DO
    function trickKey(trick) {
        if (!trick)
            return ""
        var out = []
        for (var i = 0; i < trick.length; i++)
            out.push(trick[i][1])
        return out.join(",")
    }

    // sort, jacks then ordered by suit (clubs, diamonds, hearts, spades).
    function sortedHand(cards) {
        var order = { '♣': 0, '♦': 1, '♥': 2, '♠': 3 }
        function key(c) {
            var isJack = (c.charAt(1) === 'J') ? 0 : 1
            return isJack * 100 + (order[c.charAt(0)] || 0)
        }
        var out = cards.slice()
        out.sort(function (a, b) { return key(a) - key(b) })
        return out
    }

    function refresh() {
        var st = page.engine ? page.engine.state : {}
        if (st.hands) {
            page.hand = page.sortedHand(st.hands[0])
            page.hands = [st.hands[0].slice(), st.hands[1].slice(), st.hands[2].slice()]
        } else {
            page.hand = []
            page.hands = [[], [], []]
        }
        // Keep cards a constant size: track the largest hand seen this game.
        var m = 0
        for (var i = 0; i < page.hands.length; ++i)
            m = Math.max(m, page.hands[i].length)
        if (m > page.maxHand)
            page.maxHand = m
        page.skat = st.skat ? st.skat.slice() : []
        page.trick = st.currentTrick ? st.currentTrick.slice() : []
        page.tricks = st.tricks ? st.tricks.slice() : []
        // hold last trick so all three of its cards are visible.
        var key = page.trickKey(st.lastTrick)
        if (key !== page.lastTrickKey) {
            page.lastTrick = st.lastTrick ? st.lastTrick.slice() : null
            page.lastTrickKey = key
            if (key !== "") {
                page.settling = true
                settleTimer.restart()
            } else {
                page.settling = false
                settleTimer.stop()
            }
        }
        page.declaredGame = (st.game && st.game.suit) ? st.game : null
        // state.player is null (nobody declared, e.g. all-pass) or a player
        // index once someone declares; both must map to "no declarer" (-1).
        page.declarer = (st.player == null) ? -1 : st.player
        if (page.finished)
            page.result = page.engine.getResult()
        page.selected = []
        page.schneider = false
        page.schwarz = false
        page.ouvert = false
    }

    function scoreGame() {
        var s = page.matchScore.slice()
        var pts = page.result.points || []
        var text = []
        for (var i = 0; i < 3; ++i) {
            // result.points[i] holds that player's [label, value] change
            // entries (e.g. [[ "points", -48 ]]); sum the numeric values.
            var p = 0
            var slot = pts[i] || []
            if (typeof slot === "number") {
                p = slot
            } else {
                for (var j = 0; j < slot.length; ++j) {
                    var e = slot[j]
                    if (typeof e === "number")
                        p += e
                    else if (e && typeof e[1] === "number")
                        p += e[1]
                }
            }
            s[i] += p
            text.push(page.playerName(i) + " " + (p >= 0 ? "+" : "−") + Math.abs(p))
        }
        page.matchScore = s
        var who = (page.result.player === undefined) ? "" : page.playerName(page.result.player)
        page.lastGameText = qsTr("%1 declared %2 and %3 — %4")
            .arg(who)
            .arg(page.gameText())
            .arg(page.result.outcome === "win" ? qsTr("won") : qsTr("lost"))
            .arg(text.join(", "))
    }

    // the bots take turns bidding with fixed semi random intervals
    function scheduleBots() {
        var botSteps = { "ask-bid": 1, "ask-ack": 1, "ask-declare": 1, "ask-skat": 1, "ask-card": 1 }
        if (page.actor !== null && page.actor > 0 && botSteps[page.step] && page.engine) {
            botTimer.interval = (page.step === "ask-card")
                ? 300 + Math.floor(Math.random() * 600)
                : 2000 + Math.floor(Math.random() * 2000)
            botTimer.restart()
        }
    }

    function cardValid(card) {
        if (!page.declaredGame)
            return false
        return Skaat.Util.isValidTrickCard(card, page.trick, page.hand, page.declaredGame.suit)
    }

    // Card placement: where each of the 32 cards sits, in root coordinates.
    // All the cards live in one persistent layer (cardLayer), so a card
    // simply glides to wherever the game puts it, and PlayingCard flips it
    // whenever its face changes along the way. Cards the engine has played
    // (and no longer holds) lie face down in the discard pile, in play order.
    function computePlaces() {
        var cw = page.cardWidth
        var ch = page.cardHeight
        var w = page.width
        var p = {}
        var i, n, k

        // Base: the whole pack, waiting face down in the discard pile.
        for (i = 0; i < Skaat.skatCardIds.length; ++i)
            p[Skaat.skatCardIds[i]] = { x: page.margin, y: trickRow.y, z: 5,
                    down: true, w: cw, h: ch, delay: 0, role: "pile" }
        // Played cards fan out of that spot, in play order.
        k = 0
        for (i = 0; i < page.tricks.length; ++i) {
            for (var j = 0; j < page.tricks[i].length; ++j) {
                p[Skaat.toCardId(page.tricks[i][j][1])] = { x: page.margin + k * 2, y: trickRow.y + k * 2,
                        z: 5 + k, down: true, w: cw, h: ch, delay: 0, role: "pile" }
                ++k
            }
        }

        // The bots' fans, face down.
        n = page.hands[1].length
        for (i = 0; i < n; ++i)
            p[Skaat.toCardId(page.hands[1][i])] = { x: seat1.x + i * page.botCardW * 0.32, y: seat1.y,
                    z: 10 + i, down: true, w: page.botCardW, h: page.botCardH, delay: 0, role: "bot" }
        n = page.hands[2].length
        for (i = 0; i < n; ++i)
            p[Skaat.toCardId(page.hands[2][i])] = { x: seat2.x + (n - 1 - i) * page.botCardW * 0.32, y: seat2.y,
                    z: 20 + i, down: true, w: page.botCardW, h: page.botCardH, delay: 0, role: "bot" }

        // The skat, face down until the game is declared.
        n = page.skat.length
        for (i = 0; i < n; ++i)
            p[Skaat.toCardId(page.skat[i])] = { x: skatSlot.x + i * (cw + page.pad), y: skatRow.y,
                    z: 30 + i, down: !page.skatRevealed, w: cw, h: ch, delay: i * 60, role: "skat" }

        // The trick on the table, enlarged.
        n = page.displayTrick.length
        for (i = 0; i < n; ++i)
            p[Skaat.toCardId(page.displayTrick[i][1])] = { x: w / 2 - cw * 0.65 + i * cw * 0.45,
                    y: trickRow.y + i * ch * 0.3, z: 100 + i, down: false, delay: 0, role: "trick",
                    w: cw * 1.3, h: ch * 1.3 }

        // The human hand, centred; the stagger lets the deal cascade out.
        n = page.hand.length
        var x0 = (w - cw - (n - 1) * cw * page.spread) / 2
        for (i = 0; i < n; ++i)
            p[Skaat.toCardId(page.hand[i])] = { x: x0 + i * cw * page.spread, y: handRow.y,
                    z: 50 + i, down: false, w: cw, h: ch, delay: i * 25, role: "hand" }
        return p
    }

    // Human player actions.
    function doBid(value) { page.advance("bid", 0, value) }
    function doPass() { page.advance("pass", 0) }
    function doAck() { page.advance("ack", 0) }
    function takeSkat() { page.advance("pick-skat", 0) }

    function declare(suit) {
        var mods = 0
        if (suit !== Skaat.Constants.Null) {
            if (page.schneider)
                mods |= Skaat.Constants.Schneider
            if (page.schwarz)
                mods |= Skaat.Constants.Schwarz
        }
        // Ouvert is legal for all game types (null-ouvert is a fixed value).
        if (page.ouvert)
            mods |= Skaat.Constants.Overt
        page.advance("declare", 0, { "suit": suit, "modifiers": mods })
    }

    function dropSkat() {
        if (page.selected.length !== 2)
            return
        console.log("skaat dropSkat " + page.selected.join(","))
        page.advance("put-skat", 0, page.selected)
    }

    function giveUp() {
        if (!page.playing || page.actor !== 0)
            return
        page.advance("give-up", 0)
    }

    function onCardTapped(card) {
        if (page.actor !== 0)
            return
        if (page.step === "ask-skat") {
            var sel = page.selected.slice()
            var i = sel.indexOf(card)
            if (i >= 0)
                sel.splice(i, 1)
            else if (sel.length < 2)
                sel.push(card)
            else
                sel = [sel[1], card]
            page.selected = sel
        } else if (page.step === "ask-card") {
            if (!page.cardValid(card)) {
                page.errorText = qsTr("You must follow the suit, or trump it.")
                return
            }
            page.advance("play-card", 0, card)
        }
    }

    // Table.

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        //boundsBehavior: Flickable.StopAtBounds
        contentWidth: page.width
        contentHeight: Math.max(page.height, root.contentH)
        PullDownMenu {
            MenuItem {
                text: qsTr("New game")
                onClicked: page.newGame()
            }
            MenuItem {
                text: qsTr("Rules")
                onClicked: pageStack.push(Qt.resolvedUrl("RulesPage.qml"))
            }
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }
        Item {
            id: root
            width: page.width
            height: Math.max(page.height, root.contentH)

            readonly property real topPad: Screen.topCutout ? Screen.topCutout.height + page.pad : page.pad
            readonly property real bottomPad: Screen.bottomCutout ? Screen.bottomCutout.height + page.pad : page.pad
            readonly property real contentH: handRow.y + handRow.height + root.bottomPad

            // Bot 1 (left).
            Item {
                id: seat1
                x: page.margin
                y: root.topPad
                width: page.botFanW + 10
                height: root.botRowH

                Label {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: qsTr("Bot 1") + "  " + page.matchScore[1] + page.scoreSuffix(1)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Cards.playerColor(1)
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    y: -Theme.paddingSmall
                    width: 10
                    height: 10
                    radius: 5
                    color: Cards.playerColor(1)
                    opacity: page.actor === 1 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            // Bot 2 (right).
            Item {
                id: seat2
                anchors.right: parent.right
                anchors.rightMargin: page.margin
                y: root.topPad
                width: page.botFanW + 10
                height: root.botRowH

                Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: qsTr("Bot 2") + "  " + page.matchScore[2] + page.scoreSuffix(2)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Cards.playerColor(2)
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    y: -Theme.paddingSmall
                    width: 10
                    height: 10
                    radius: 5
                    color: Cards.playerColor(2)
                    opacity: page.actor === 2 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            readonly property real botRowH: page.botCardH + Theme.fontSizeSmall + 2 * Theme.paddingSmall

            // The skat.
            Item {
                id: skatRow
                y: seat1.y + seat1.height + page.pad
                width: parent.width
                height: page.cardHeight

                Item {
                    id: skatSlot
                    x: (parent.width - (2 * page.cardWidth + page.pad)) / 2
                    y: 0
                    width: 2 * page.cardWidth + page.pad
                    height: parent.height

                    //DashedSlot {
                    //    anchors.fill: parent
                    //}
                }
            }

            // The current trick.
            Item {
                id: trickRow
                y: skatRow.y + skatRow.height + page.pad
                width: parent.width
                height: Math.round(page.cardHeight * 1.8)
            }

            // Status and actions.
            Column {
                id: statusBlock
                x: page.margin
                y: trickRow.y + trickRow.height + page.pad * 2
                width: page.width - 2 * page.margin
                spacing: page.pad

                Label {
                    id: bidChip
                    visible: (page.step === "ask-bid" || page.step === "ask-ack") && page.bidChipText() !== ""
                    width: parent.width
                    text: page.bidChipText()
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    color: Theme.highlightColor
                }

                Label {
                    id: statusLabel
                    width: parent.width
                    text: page.statusText()
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeMedium
                }

                Flow {
                    id: actionFlow
                    width: parent.width
                    spacing: Theme.paddingSmall

                    // --- bidding ---
                    Row {
                        visible: page.actor === 0 && page.step === "ask-bid"
                        spacing: Theme.paddingSmall
                        Button {
                            text: qsTr("Pass")
                            onClicked: page.doPass()
                        }
                        Button {
                            id: bidBtn
                            text: qsTr("Bid")
                            onClicked: bidMenu.visible = true
                        }
                    }
                    ComboBox {
                        visible: false
                        width: parent.width
                        id: bidMenu
                        menu: ContextMenu {
                            Repeater {
                                model: page.bidList
                                MenuItem {
                                    text: String(modelData)
                                    onClicked: page.doBid(modelData)
                                }
                            }
                        }
                    }

                    // --- contra ---
                    Row {
                        visible: page.actor === 0 && page.step === "ask-ack"
                        spacing: Theme.paddingSmall
                        Button {
                            text: qsTr("Contra")
                            onClicked: page.doAck()
                        }
                        Button {
                            text: qsTr("Pass")
                            onClicked: page.doPass()
                        }
                    }

                    // --- declaration ---
                    // "Take skat" is the primary action; the games and the
                    // Schneider/Schwarz modifiers live in the context menu.
                    Row {
                        visible: page.actor === 0 && page.step === "ask-declare"
                        spacing: Theme.paddingSmall
                        Button {
                            text: qsTr("Put skat")
                            onClicked: page.takeSkat()
                        }
                        Button {
                            id: declareBtn
                            text: qsTr("Declare")
                            onClicked: declareMenu.visible = true
                        }

                    }
                    ComboBox {
                        visible: false
                        width: parent.width
                        id: declareMenu
                        menu: ContextMenu {
                            MenuItem {
                                text: (page.schneider ? "✓ " : "") + qsTr("Schneider")
                                onClicked: page.schneider = !page.schneider
                            }
                            MenuItem {
                                text: (page.schwarz ? "✓ " : "") + qsTr("Schwarz")
                                onClicked: page.schwarz = !page.schwarz
                            }
                            MenuItem {
                                text: (page.ouvert ? "✓ " : "") + qsTr("Ouvert")
                                onClicked: page.ouvert = !page.ouvert
                            }
                            MenuItem {
                                text: qsTr("Grand")
                                onClicked: page.declare(Skaat.Constants.Grand)
                            }
                            MenuItem {
                                text: qsTr("Null")
                                onClicked: page.declare(Skaat.Constants.Null)
                            }
                            MenuItem {
                                text: "♣"
                                onClicked: page.declare(Skaat.Constants.Clubs)
                            }
                            MenuItem {
                                text: "♦"
                                onClicked: page.declare(Skaat.Constants.Diamonds)
                            }
                            MenuItem {
                                text: "♥"
                                onClicked: page.declare(Skaat.Constants.Hearts)
                            }
                            MenuItem {
                                text: "♠"
                                onClicked: page.declare(Skaat.Constants.Spades)
                            }
                        }
                    }

                    // --- dropping the skat ---
                    Row {
                        visible: page.actor === 0 && page.step === "ask-skat"
                        Button {
                            text: qsTr("Drop %1 of 2").arg(page.selected.length)
                            enabled: page.selected.length === 2
                            onClicked: page.dropSkat()
                        }
                    }

                    // --- give up ---
                    Row {
                        visible: page.actor === 0 && page.step === "ask-card"
                              && page.playing
                              && page.declaredGame.suit !== Skaat.Constants.Ramsch
                        Button {
                            text: qsTr("Resign")
                            onClicked: page.giveUp()
                        }
                    }

                    // --- a new game ---
                    Row {
                        visible: page.finished || page.allPass
                        Button {
                            text: qsTr("New game")
                            onClicked: page.newGame()
                        }
                    }
                }
            }


            // The human hand.
            Item {
                id: handRow
                anchors.bottom: parent.bottom
                anchors.bottomMargin: page.cardHeight /2
                width: parent.width
                height: page.cardHeight
            }

            // The human's running total, mirroring the bot seats. Sits just
            // above the (wide, centred) hand fan so it never overlaps a card.
            Label {
                id: youLabel
                anchors.left: parent.left
                anchors.bottom: handRow.top
                anchors.leftMargin: page.margin
                anchors.bottomMargin: page.pad
                text: qsTr("You") + "  " + page.matchScore[0] + page.scoreSuffix(0)
                font.pixelSize: Theme.fontSizeSmall
                color: Cards.playerColor(0)
            }

            // All 32 cards live here and glide to wherever the game puts
            // them: the hand, the bots' fans, the skat, the table, or the
            // discard pile. They flip over whenever their face changes.
            Repeater {
                id: cardLayer
                model: Skaat.skatCardIds

                TableCard {
                    readonly property int cid: modelData
                    readonly property string cardName: Skaat.fromCardId(cid)
                    readonly property bool inHand: place.role === "hand"

                    place: page.places[cid]
                    cardId: cid
                    width: place.w
                    height: place.h
                    selected: inHand && page.selected.indexOf(cardName) >= 0
                    dimmed: inHand && page.step === "ask-card" && page.actor === 0
                          && !page.cardValid(cardName)
                    enabled: inHand && ((page.step === "ask-skat" && page.actor === 0)
                                  || (page.step === "ask-card" && page.actor === 0
                                      && page.cardValid(cardName)))
                    onClicked: page.onCardTapped(cardName)
                }
            }
        }
    }

    // Bots move at this pace.
    Timer {
        id: botTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (!page.engine || page.actor === null || page.actor < 1)
                return
            // Let a just-completed trick stay on the table for the full
            // settle window before the next card glides in.
            if (page.settling) {
                botTimer.interval = 250
                botTimer.restart()
                return
            }
            var move
            try {
                move = page.bots[page.actor].next(page.engine, page.step, page.actor)
            } catch (err) {
                page.errorText = qsTr("Bot error: %1").arg(String(err && err.message || err))
                return
            }
            page.advance(move[0], page.actor, move[1], move[2])
        }
    }

    // Hold a completed trick on the table for a moment so all three cards
    // can be seen before the next trick begins.
    Timer {
        id: settleTimer
        interval: 2000
        repeat: false
        onTriggered: page.settling = false
    }

    Component.onCompleted: page.newGame()


}
