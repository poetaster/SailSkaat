import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.Portrait

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Skat") }

            Repeater {
                model: [
                    { title: qsTr("The deal"),
                      text: qsTr("Each player is dealt ten cards and the two remaining ones are laid face down in the middle of the table as the skat. Dealing runs in the pattern three cards each, skat, four cards, three again.") },
                    { title: qsTr("Bidding"),
                      text: qsTr("Before the hand is played, players bid to decide who is declarer and the minimum game value declarer must win. A player may pass or bid any value higher than the current one; the lowest bid is 18. Bidding ends as soon as two players have passed, and the player left with the highest accepted bid is declarer. If everyone passes, no points are scored and the hand is re-dealt.") },
                    { title: qsTr("Game value"),
                      text: qsTr("Game value = base value × game level. The base values are ♣ 12, ♠ 11, ♥ 10, ♦ 9, and 24 for a grand game (only the jacks are trumps). The level starts at 1 and rises with the number of matadors and with hand, schneider or schwarz, both when declared and when achieved. Example: 3 matadors + hand + declared schneider = level 6.") },
                    { title: qsTr("Matadors"),
                      text: qsTr("The jacks rank ♣, ♠, ♥, ♦ and are followed by the trump suit's A, 10, K, Q, 9, 8, 7. Consecutive cards counting down from the jack of clubs count as \"with\": J♣ J♠ A♥ 10♥ is \"with 4\". If the jack of clubs is missing, consecutive jacks from the top count as \"without\": J♥ J♦ is \"without 2\".") },
                    { title: qsTr("Declaring"),
                      text: qsTr("Declarer picks up the skat, looks at both cards, puts two back face down, and declares a suit or grand. With a hand game the skat is not picked up. Declarer may also announce schneider (defenders must score 30 points or fewer) or schwarz (take all ten tricks).") },
                    { title: qsTr("The play"),
                      text: qsTr("Each trick is one card from each player, and the winner of a trick leads the next one. If the led suit has been played and is not trump, a higher card of the same suit wins; otherwise the highest trump takes the trick. In a null game there is no trump, and the cards rank A, K, Q, J, 10, 9, 8, 7 in every suit.") },
                    { title: qsTr("Scoring"),
                      text: qsTr("Card points: 10 = 10, A = 11, K = 4, Q = 3, J = 2, the rest 0. Declarer wins a suit or grand game with 61 points or more, with 91 or more if schneider was declared, or with all ten tricks if schwarz. In a null game the game value is 23 (35 for a null hand) and declarer must take no tricks at all. The winner gains the game value, each loser loses it.") },
                    { title: qsTr("Playing here"),
                      text: qsTr("In the bidding, tap Pass or choose a value. As declarer, tap the skat to look at it and put two cards back, or declare a hand game, and check Schneider, Schwarz or Ouvert if you can make them. Then tap a card to play it; dimmed cards are not allowed. The bots bid and play on a short delay.") }
                ]
                Column {
                    width: column.width
                    SectionHeader { text: modelData.title }
                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        text: modelData.text
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
