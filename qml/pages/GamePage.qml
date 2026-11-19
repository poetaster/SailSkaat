import QtQuick 2.6

import Sailfish.Silica 1.0
import "../js/skaat.js" as Skaat
import "../cards"
import "../cards/cards.js" as Cards
import "../components"

// The Skat table. The game engine is plain JavaScript (qml/js/skaat.js);
// this page mirrors its state into QML bindings, drives the bots with a
// timer, and maps the card names to the sailfish-cards id space.

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
    property var result: null
    property var declaredGame: null
    property int declarer: -1
    property var matchScore: [0, 0, 0]

    // Choices in progress.
    property var selected: []
    property bool schneider: false
    property bool schwarz: false
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

    // Table sizing.
    readonly property real margin: Theme.horizontalPageMargin
    readonly property real pad: Theme.paddingMedium
    // Layout is sized off the largest hand dealt this game (not the live
    // hand size), so cards keep a constant size as the hand shrinks during
    // play. The live handCount is still used to centre the fan.
    readonly property int handCount: Math.max(1, page.hand.length)
    property int maxHand: 1
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

    // Skat is laid face up once someone has declared; until then it waits
    // in its slot face down, the way a real table keeps it.
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

    function gameText() {
        if (!page.declaredGame)
            return ""
        var text = page.suitText(page.declaredGame.suit)
        var m = page.declaredGame.modifiers || 0
        if (m & Skaat.Constants.Hand)
            text += " " + qsTr("Hand")
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
        if (page.step === "ask-bid")
            return who + (page.actor === 0 ? qsTr("must bid: pass or name a bid.") : qsTr("is weighing the cards…"))
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

    // Bids allowed now: everything above the current bid.
    readonly property var bidList: {
        var bid = (page.engine && page.engine.state.bidding) ? page.engine.state.bidding.bid : null
        var out = []
        for (var i = 0; i < Skaat.BIDS.length; ++i)
            if (Skaat.BIDS[i] > (bid || 0))
                out.push(Skaat.BIDS[i])
        return out
    }

    // ------------------------------------------------------------------
    // Engine drivers.
    // ------------------------------------------------------------------

    function newGame() {
        page.selected = []
        page.schneider = false
        page.schwarz = false
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

    // A stable key for a trick (the list of cards it holds), so we can tell
    // when a new trick has completed as opposed to the same one re-read.
    function trickKey(trick) {
        if (!trick)
            return ""
        var out = []
        for (var i = 0; i < trick.length; i++)
            out.push(trick[i][1])
        return out.join(",")
    }

    // Display order for the human's hand: jacks first, then the rest; each
    // group ordered by suit (clubs, diamonds, hearts, spades).
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
        // A trick just completed when the in-progress trick is empty but a new
        // lastTrick has appeared. Hold that finished trick on the table for a
        // short settle period so all three of its cards are visible.
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
        page.declarer = (st.player === undefined) ? -1 : st.player
        if (page.finished)
            page.result = page.engine.getResult()
        page.selected = []
        page.schneider = false
        page.schwarz = false
    }

    function scoreGame() {
        var s = page.matchScore.slice()
        var pts = page.result.points || []
        var text = []
        for (var i = 0; i < 3; ++i) {
            // result.points[i] holds that player's [label, value] change
            // entries (e.g. [[ "points", -48 ]]); sum the numeric values.
            // Tolerate a bare number or an empty slot as well.
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

    function scheduleBots() {
        var botSteps = { "ask-bid": 1, "ask-ack": 1, "ask-declare": 1, "ask-skat": 1, "ask-card": 1 }
        if (page.actor !== null && page.actor > 0 && botSteps[page.step] && page.engine) {
            botTimer.interval = (page.step === "ask-card")
                ? 300 + Math.floor(Math.random() * 600)
                : 1000 + Math.floor(Math.random() * 2000)
            botTimer.restart()
        }
    }

    function cardValid(card) {
        if (!page.declaredGame)
            return false
        return Skaat.Util.isValidTrickCard(card, page.trick, page.hand, page.declaredGame.suit)
    }

    // Card placements, built in JS: an inline object literal in binding
    // position would be parsed as an inline component.
    function botPlace(player, index) {
        var n = page.hands[player].length
        var i = (player === 1) ? index : (n - 1 - index)
        return { "x": i * page.botCardW * 0.32, "y": 0, "z": 10 + player * 10 + index, "down": true }
    }

    function skatPlace(index) {
        return { "x": index * (page.cardWidth + page.pad), "y": 0, "z": 30 + index, "down": !page.skatRevealed }
    }

    function trickPlace(index) {
        return { "x": root.width / 2 - page.cardWidth / 2 + index * page.cardWidth * 0.45,
                 "y": index * page.cardHeight * 0.3,
                 "z": 100 + index, "down": false }
    }

    function handPlace(index) {
        var x0 = (page.width - page.cardWidth - (page.handCount - 1) * page.cardWidth * page.spread) / 2
        return { "x": x0 + index * page.cardWidth * page.spread, "y": 0, "z": index, "down": false }
    }

    // ------------------------------------------------------------------
    // Human actions.
    // ------------------------------------------------------------------

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

    // ------------------------------------------------------------------
    // Table.
    // ------------------------------------------------------------------

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: page.width
        contentHeight: Math.max(page.height, root.contentH)

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

                Repeater {
                    model: page.hands[1].length
                    TableCard {
                        place: page.botPlace(1, index)
                        cardId: -1
                        faceDown: true
                        width: page.botCardW
                        height: page.botCardH
                        enabled: false
                    }
                }
                Label {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: qsTr("Bot 1") + "  " + page.matchScore[1]
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

                Repeater {
                    model: page.hands[2].length
                    TableCard {
                        place: page.botPlace(2, index)
                        cardId: -1
                        faceDown: true
                        width: page.botCardW
                        height: page.botCardH
                        enabled: false
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: qsTr("Bot 2") + "  " + page.matchScore[2]
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

            readonly property real botRowH: page.botCardH + 2 * Theme.paddingSmall

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
                    Repeater {
                        model: 2
                        TableCard {
                            readonly property string cardName: page.skat[index]
                            readonly property bool revealed: page.skatRevealed && cardName
                            place: page.skatPlace(index)
                            cardId: revealed ? Skaat.toCardId(cardName) : -1
                            faceDown: !revealed
                            width: page.cardWidth
                            height: page.cardHeight
                            enabled: false
                        }
                    }
                }
            }

            // The current trick.
            Item {
                id: trickRow
                y: skatRow.y + skatRow.height + page.pad
                width: parent.width
                height: Math.round(page.cardHeight * 1.8)

                Repeater {
                    model: page.displayTrick.length
                    TableCard {
                        readonly property string cardName: page.displayTrick[index][1]
                        place: page.trickPlace(index)
                        cardId: Skaat.toCardId(cardName)
                        faceDown: false
                        width: page.cardWidth
                        height: page.cardHeight
                        enabled: false
                    }
                }
            }

            // Status and actions.
            Column {
                id: statusBlock
                x: page.margin
                y: trickRow.y + trickRow.height + page.pad
                width: page.width - 2 * page.margin
                spacing: page.pad

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
                    }
                    Repeater {
                        model: page.actor === 0 && page.step === "ask-bid" ? page.bidList : []
                        Button {
                            text: String(modelData)
                            onClicked: page.doBid(modelData)
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
                            text: qsTr("Take skat")
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
                            text: qsTr("Give up")
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
                //y: statusBlock.y + statusBlock.height + page.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: page.cardHeight /2
                width: parent.width
                height: page.cardHeight

                Repeater {
                    model: page.hand.length
                    TableCard {
                        readonly property string cardName: page.hand[index]
                        readonly property int cid: Skaat.toCardId(cardName)
                        place: page.handPlace(index)
                        cardId: cid
                        faceDown: false
                        width: page.cardWidth
                        height: page.cardHeight
                        selected: page.selected.indexOf(cardName) >= 0
                        dimmed: page.step === "ask-card" && page.actor === 0 && !page.cardValid(cardName)
                        enabled: (page.step === "ask-skat" && page.actor === 0)
                              || (page.step === "ask-card" && page.actor === 0 && page.cardValid(cardName))
                        onClicked: page.onCardTapped(cardName)
                    }
                }
            }

            // The human's running total, mirroring the bot seats. Sits just
            // above the (wide, centred) hand fan so it never overlaps a card.
            Label {
                id: youLabel
                anchors.left: parent.left
                anchors.bottom: handRow.top
                anchors.leftMargin: page.margin
                anchors.bottomMargin: page.pad
                text: qsTr("You") + "  " + page.matchScore[0]
                font.pixelSize: Theme.fontSizeSmall
                color: Cards.playerColor(0)
            }
        }
    }

    // Bots move at their own pace, not ours.
    Timer {
        id: botTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (!page.engine || page.actor === null || page.actor < 1)
                return
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

    PullDownMenu {
        MenuItem {
            text: qsTr("New game")
            onClicked: page.newGame()
        }
        MenuItem {
            text: qsTr("About")
            onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
        }
    }
}
