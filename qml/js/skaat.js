.pragma library

/*
 * Skat game engine for SailSkaat.
 *
 * Bundled from the skaat JavaScript engine (https://github.com/nikku/skaat):
 * Constants.js, StateMachine.js, Util.js, Results.js, Game.js, Automa.js,
 * with the ES module syntax removed so it can be imported by QML, plus a
 * small adapter to the sailfish-cards card id space and a self test.
 */

/* ================================ Constants.js ================================ */
var Seven = '7';
var Eight = '8';
var Nine = '9';
var Ten = '10';
var Jack = 'J';
var Queen = 'Q';
var King = 'K';
var Ace = 'A';

var Grand = 'G';
var Null = 'N';
var Ramsch = 'R';

var Clubs = '♣';
var Spades = '♠';
var Hearts = '♥';
var Diamonds = '♦';

/* eslint no-multi-spaces: "off" */
var Schneider     = 1;
var Schwarz       = 2;

var Contra        = 4;
var Re            = 12;
var Bock          = 28;

var Overt         = 32;
var Hand          = 64;

var NoModifiers   = 0;
var AllModifiers  = 127;

var Win = 'win';
var Loss = 'loss';

/**
 * @typedef { import("./types").ColorSuit } ColorSuit
 * @typedef { import("./types").Suit } Suit
 * @typedef { import("./types").Card } Card
 * @typedef { import("./types").Picture } Picture
 */

/**
 * @type { ColorSuit[] }
 */
var ColorSuits = [
  Clubs,
  Spades,
  Hearts,
  Diamonds
];

/**
 * @type { Picture[] }
 */
var Pictures = [
  Ace,
  Ten,
  King,
  Queen,
  Jack,
  Nine,
  Eight,
  Seven
];

/**
 * @type { Record<Picture, number> }
 */
var PictureValues = {};
PictureValues[Seven] = 0;
PictureValues[Eight] = 0;
PictureValues[Nine] = 0;
PictureValues[Ten] = 10;
PictureValues[Jack] = 2;
PictureValues[Queen] = 3;
PictureValues[King] = 4;
PictureValues[Ace] = 11;

/**
 * @type { Card[] }
 */
var AllCards = /** @type { Card[] } */ (
  (function () {
    var cards = []
    for (var si = 0; si < ColorSuits.length; si++)
      for (var pi = 0; pi < Pictures.length; pi++)
        cards.push(ColorSuits[si] + Pictures[pi])
    return cards
  })()
);

/**
 * @typedef { Record<Card, [ ColorSuit, Picture ]>} CardComponents
 */

/**
 * @type { CardComponents }
 */
var CardComponents = (function () {
  var components = {}
  for (var i = 0; i < AllCards.length; i++) {
    var card = AllCards[i]
    components[card] = /^(♣|♠|♥|♦)(.*)$/.exec(card).slice(1)
  }
  return components
})()

/**
 * @typedef { Record<Card, number>} CardValues
 */

/**
 * @type { CardValues }
 */
var CardValues = (function () {
  var values = {}
  for (var i = 0; i < AllCards.length; i++) {
    var card = AllCards[i]
    values[card] = PictureValues[CardComponents[card][1]]
  }
  return values
})()

/**
 * @type { Suit[] }
 */
var AllSuits = [ Clubs, Spades, Hearts, Diamonds, Grand, Ramsch, Null ];

/* ================================ StateMachine.js ================================ */
/* global console */

/**
 * @typedef { [ next: string, actor: number ] | string } StepResult
 * @typedef { (...args: any[]) => StepResult } StepFunction
 * @typedef { [ start: string, next: string, fn: StepFunction ] | [ start: string, fn: StepFunction ] | [ end: string ] } StepDefinition
 * @typedef { { verbose?: boolean; steps: StepDefinition[] } } StateMachineOptions
 * @typedef { { state: string, expectedActor: number } } StateMachineStart
 */

/**
 * @param { StateMachineOptions } options
 * @param { StateMachineStart } [start]
 */
function StateMachine(options, start) {

  var state = start && start.state || 'initial';
  var expectedActor = start && start.expectedActor || null;

  var verbose = options.verbose || false;

  var steps = {};
  for (var stepIndex = 0; stepIndex < options.steps.length; stepIndex++) {
    var step = options.steps[stepIndex];
    var stateName;
    var action;

    // default action
    if (step.length === 2) {
      stateName = step[0];
      action = step[1];

      if (steps[stateName]) {
        throw new Error('state <' + stateName + '> definition error: default action already registered');
      }

      steps[stateName] = { action: action };
      continue;
    }

    // user action
    if (step.length === 3) {
      stateName = step[0];
      var nextName = step[1];
      action = step[2];

      steps[stateName] = steps[stateName] || { paths: {} };

      if (steps[stateName].action) {
        throw new Error('state <' + stateName + '> definition error: mixing default and explicit actions');
      }

      steps[stateName].paths[nextName] = action;
      continue;
    }

    // end
    if (step.length === 1) {
      stateName = step[0];
      steps[stateName] = {};
      continue;
    }

    throw new Error('invalid step definition');
  }

  if (!steps[state]) {
    throw new Error('state <' + state + '> required');
  }

  /**
   * @param {string} nextState
   * @param {number} [actor]
   * @param {...unknown} args
   *
   * @return { [ next: string, actor: number | null ] }
   */
  function next(nextState) {
    var actor = arguments[1] === undefined ? null : arguments[1];
    var args = Array.prototype.slice.call(arguments, 2);

    verbose && console.log('next START <' + printActor(actor) + '> ' + state + ' -> ' + nextState, args);

    var stateDefinition = steps[state];

    var paths = stateDefinition.paths;

    if (!paths) {
      verbose && console.error('next ERROR no paths transitions for state ' + state);

      throw new Error('no paths transitions for state ' + state);
    }

    var transition = paths[nextState];

    if (!transition) {
      verbose && console.error('next ERROR no transition ' + state + ' -> ' + nextState);

      throw new Error('no transition ' + state + ' -> ' + nextState);
    }

    if (actor !== expectedActor) {
      verbose && console.error('next ERROR expected actor <' + printActor(expectedActor) + '>, found <' + printActor(actor) + '>');

      throw new Error('unexpected actor <' + printActor(actor) + '>');
    }

    verbose && console.log('take TRANSITION ' + state + ' -> ' + nextState);

    var result = transition.apply(null, [ actor ].concat(args));

    var nextLoopState;
    while (result) {

      var resultArr = Array.isArray(result) ? result : [ result ];
      nextLoopState = resultArr[0];
      var nextActor = resultArr[1] === undefined ? null : resultArr[1];

      expectedActor = nextActor;
      state = nextLoopState;

      if (state === 'end') {
        break;
      }

      stateDefinition = steps[state];

      transition = stateDefinition.action;

      if (!transition) {
        break;
      }

      verbose && console.log('take DEFAULT TRANSITION ' + state);

      result = transition();
    }

    verbose && console.log('next END ' + state);

    return [ state, expectedActor ];
  }

  // api ////////////////

  this.next = next;
}


// helpers ///////////////

function printActor(actor) {
  return typeof actor === 'undefined' ? 'null' : actor;
}

/* ================================ Util.js ================================ */

/**
 * @typedef { import('./types').Card } Card
 * @typedef { import('./types').Trick } Trick
 * @typedef { import('./types').Suit } Suit
 * @typedef { import('./types').Picture } Picture
 * @typedef { import('./types').Player } Player
 */

function scoreKeyed(arr) {
  var score = {}
  for (var i = 0; i < arr.length; i++)
    score[arr[i]] = i + 1
  return score
}

var NULL_PICTURES = [ 'A', 'K', 'Q', 'J', '10', '9', '8', '7' ];
var COLOR_PICTURES = [ 'A', '10', 'K', 'Q', '9', '8', '7' ];

var JACKS = []
for (var JACKS_i = 0; JACKS_i < ColorSuits.length; JACKS_i++)
  JACKS.push(ColorSuits[JACKS_i] + Jack)

function generateSuitCards(trumpSuit, suit) {
  var pictures = trumpSuit === Null ? NULL_PICTURES : COLOR_PICTURES
  var cards = []
  for (var p = 0; p < pictures.length; p++)
    cards.push(suit + pictures[p])
  return cards
}

var COLOR_CARDS = {}
for (var COLOR_CARDS_t = 0; COLOR_CARDS_t < AllSuits.length; COLOR_CARDS_t++) {
  var trumpSuit = AllSuits[COLOR_CARDS_t]
  var cardsBySuit = {}
  for (var COLOR_CARDS_s = 0; COLOR_CARDS_s < ColorSuits.length; COLOR_CARDS_s++)
    cardsBySuit[ColorSuits[COLOR_CARDS_s]] = generateSuitCards(trumpSuit, ColorSuits[COLOR_CARDS_s])
  COLOR_CARDS[trumpSuit] = cardsBySuit
}

var SUIT_ORDER = scoreKeyed(ColorSuits);

var TRUMP_ORDER = {}
for (var TRUMP_ORDER_i = 0; TRUMP_ORDER_i < AllSuits.length; TRUMP_ORDER_i++) {
  var tSuit = AllSuits[TRUMP_ORDER_i]

  if (tSuit === Null) {
    TRUMP_ORDER[tSuit] = scoreKeyed([])
  } else if (tSuit === Ramsch || tSuit === Grand) {
    TRUMP_ORDER[tSuit] = scoreKeyed(JACKS)
  } else {
    TRUMP_ORDER[tSuit] = scoreKeyed(JACKS.concat(COLOR_CARDS[tSuit][tSuit]))
  }
}

var COLOR_ORDER = {}
for (var COLOR_ORDER_suit in COLOR_CARDS) {
  var cardsBySuit2 = COLOR_CARDS[COLOR_ORDER_suit]
  var bySuit = {}
  for (var COLOR_ORDER_inner in cardsBySuit2)
    bySuit[COLOR_ORDER_inner] = scoreKeyed(cardsBySuit2[COLOR_ORDER_inner])
  COLOR_ORDER[COLOR_ORDER_suit] = bySuit
}

/**
 * @param {Card} card
 *
 * @return {number}
 */
function getCardValue(card) {
  return CardValues[card];
}

/**
 * @param {Card} card
 *
 * @return {[ Suit, Picture ]}
 */
function cardComponents(card) {
  return CardComponents[card];
}

/**
 * @param {Trick} trick
 * @param {Suit} trumpSuit
 *
 * @return {Player}
 */
function getTrickWinner(trick, trumpSuit) {

  var winner;

  for (var i = 0; i < trick.length; i++) {

    var part = trick[i];

    if (!winner) {
      winner = part;
    } else {

      if (beatsCompare(part[1], winner[1], trumpSuit) > 0) {
        winner = part;
      }
    }
  }

  return winner[0];
}

/**
 * @param {Card} card
 * @param {Trick} trick
 * @param {Card[]} hand
 * @param {Suit} trumpSuit
 *
 * @return {boolean}
 */
function handHas(hand, order) {
  for (var i = 0; i < hand.length; i++)
    if (order[hand[i]])
      return true
  return false
}

function isValidTrickCard(card, trick, hand, trumpSuit) {

  if (trick.length === 0) {
    return true;
  }

  var firstCard = trick[0][1];

  var trumps = TRUMP_ORDER[trumpSuit];

  if (trumps[firstCard]) {
    if (trumps[card]) {
      return true;
    }

    return !handHas(hand, trumps);
  }

  var suit = cardComponents(firstCard)[0];

  var color = COLOR_ORDER[trumpSuit][suit];

  if (color[card]) {
    return true;
  }

  return !handHas(hand, color);
}

/**
 * @param {Card} a
 * @param {Card} b
 * @param {Suit} trumpSuit
 *
 * @return {number}
 */
function beatsCompare(a, b, trumpSuit) {

  var aSuit = cardComponents(a)[0];

  var bSuit = cardComponents(b)[0];

  var trumps = TRUMP_ORDER[trumpSuit];

  if (trumps[a] && trumps[b]) {
    return trumps[b] - trumps[a];
  }

  if (trumps[a]) {
    return 1;
  }

  if (trumps[b]) {
    return -1;
  }

  if (aSuit === bSuit) {
    var colorOrder = COLOR_ORDER[trumpSuit][bSuit];

    return colorOrder[b] - colorOrder[a];
  }

  return -1;
}


/**
 * @param {Card} a
 * @param {Card} b
 * @param {Suit} trumpSuit
 * @return {number}
 */
function semanticCompare(a, b, trumpSuit) {

  var aSuit = cardComponents(a)[0];

  var bSuit = cardComponents(b)[0];

  var trumps = TRUMP_ORDER[trumpSuit];

  if (trumps[a] && trumps[b]) {
    return trumps[b] - trumps[a];
  }

  if (trumps[a]) {
    return 1;
  }

  if (trumps[b]) {
    return -1;
  }

  if (aSuit === bSuit) {
    var colorOrder = COLOR_ORDER[trumpSuit][bSuit];

    return colorOrder[b] - colorOrder[a];
  }

  return SUIT_ORDER[bSuit] - SUIT_ORDER[aSuit];
}

function semanticSort(cards, suit) {
  return cards.slice().sort(function (a, b) { return semanticCompare(a, b, suit); }).reverse();
}

/**
 * @param {Suit} suit
 * @param {Picture} picture
 *
 * @return {(Card) => boolean}
 */
function findCard(suit, picture) {
  return function (card) {
    var components = cardComponents(card);

    return components[0] === suit && components[1] === picture;
  };
}

/**
 * @param {Card[]} cards
 * @return {number}
 */
function getJacksModifier(cards) {
  var val = [];
  for (var i = 0; i < ColorSuits.length; i++) {
    var suit = ColorSuits[i];

    // skip
    if (val.length > 0 && val[2]) {
      continue;
    }

    var checker = findCard(suit, Jack);
    var foundJack = false;
    for (var c = 0; c < cards.length; c++)
      if (checker(cards[c])) {
        foundJack = true;
        break;
      }

    if (val.length === 0) {
      val = [ 1, foundJack, false ];
    } else {

      var count = val[0];
      var withJack = val[1];

      if (withJack === foundJack) {
        val = [ count + 1, withJack, false ];
      } else {
        val = [ count, withJack, true ];
      }
    }
  }

  return val[0];
}

var DEAL_SEQUENCE_STR = '11122233344111122223333111222333'
var dealSequence = []
for (var d = 0; d < DEAL_SEQUENCE_STR.length; d++)
  dealSequence.push(parseInt(DEAL_SEQUENCE_STR.charAt(d), 10))

/**
 * Dealing cards, TÜF Rheinland geprüft. 🥳
 *
 * @return { [ hands: [ Card[], Card[], Card[] ], skat: Card[] ] }
 */
function dealCards() {

  var cards = shuffle(AllCards);

  var buckets = [
    [], [], [], []
  ];

  for (var i = 0; i < dealSequence.length; i++) {
    var card = cards.pop();

    buckets[dealSequence[i] - 1].push(card);
  }

  return [
    [
      buckets[0],
      buckets[1],
      buckets[2]
    ],
    buckets[3]
  ];
}

/**
 * Shuffles an array.
 *
 * @template T
 * @param {T[]} arr
 *
 * @return {T[]}
 */
function shuffle(arr) {
  var copy = arr.slice();

  var j, x, i;
  for (i = copy.length - 1; i > 0; i--) {
    j = Math.floor(Math.random() * (i + 1));
    x = copy[i];
    copy[i] = copy[j];
    copy[j] = x;
  }

  return copy;
}

/* ================================ Results.js ================================ */


/**
 * @typedef { import('./types').Player } Player
 * @typedef { import('./types').Card } Card
 * @typedef { import('./types').State } State
 * @typedef { import('./types').Result } Result
 * @typedef { import('./types').Trick } Trick
 */

/**
 * Sum value of cards.
 *
 * @param {number} sum
 * @param {Card} card
 *
 * @return {number}
 */
function sumCards(sum, card) {
  return sum + getCardValue(card);
}

/**
 * Sum value of tricks.
 *
 * @param {Trick[]} tricks
 *
 * @return {number}
 */
function sumTricks(tricks) {
  var cards = []
  for (var i = 0; i < tricks.length; i++)
    cards.push(tricks[i][1])
  return cards.reduce(sumCards, 0)
}

function pointsDelta(players, player, points) {
  var out = []
  for (var i = 0; i < players.length; i++)
    out.push(players[i] === player ? [ [ 'points', points ] ] : [])
  return out
}

/**
 * Calculate a Ramsch result.
 *
 * @param {Player[]} players
 * @param {Partial<State>} state
 *
 * @return {Result}
 */
function calculateRamschResults(players, state) {

  var playerTricks = state.playerTricks;
  var result = state.result;

  var trickPoints = []
  for (var i = 0; i < playerTricks.length; i++)
    trickPoints.push(sumTricks(playerTricks[i]))

  var skatPoints = 0
  for (var s = 0; s < state.skat.length; s++)
    skatPoints = sumCards(skatPoints, state.skat[s])

  var max = trickPoints[0]
  for (var m = 1; m < trickPoints.length; m++)
    if (trickPoints[m] > max)
      max = trickPoints[m]

  var looser = trickPoints.indexOf(max);

  var points = max + skatPoints;

  var merged = {}
  for (var k in result)
    merged[k] = result[k]
  merged.outcome = Loss
  merged.player = looser
  merged.points = pointsDelta(players, looser, -points)
  return merged
}

/**
 * Calculate a Null result.
 *
 * @param {Player[]} players
 * @param {Partial<State>} state
 *
 * @return {Result}
 */
function calculateNullResults(players, state) {

  var game = state.game;
  var player = state.player;
  var playerTricks = state.playerTricks;

  var modifiers = game.modifiers;

  var result = state.result || {};

  var outcome = result.outcome || (playerTricks[player].length === 0 ? Win : Loss);

  var modifierMap = {}
  modifierMap[0] = 23
  modifierMap[Hand] = 35
  modifierMap[Overt] = 46
  modifierMap[Hand | Overt] = 59

  var basePoints = modifierMap[modifiers & (Hand | Overt)];

  var points = (
    (basePoints) *
    (outcome === Win && 1 || -2) *
    (modifiers & Contra && 2 || 1) *
    (modifiers & Re && 2 || 1) *
    (modifiers & Bock && 2 || 1)
  );

  var merged = {}
  for (var k in result)
    merged[k] = result[k]
  merged.outcome = outcome
  merged.player = player
  merged.points = pointsDelta(players, player, points)
  return merged
}

/**
 * Calculate a suit (or Grand) result
 *
 * @param {Player[]} players
 * @param {Partial<State>} state
 *
 * @return {Result}
 */
function calculateSuitResults(players, state) {

  var game = state.game;
  var player = state.player;
  var playerTricks = state.playerTricks;

  var suit = game.suit;
  var modifiers = game.modifiers;
  var jacks = game.jacks;

  var result = state.result || {};

  var valueMap = {}
  valueMap[Clubs] = 12
  valueMap[Spades] = 11
  valueMap[Hearts] = 10
  valueMap[Diamonds] = 9
  valueMap[Grand] = 24

  // TODO: add remaining cards to player, if enemy gave up
  var tricksValue = sumTricks(playerTricks[player]);

  var outcome = result.outcome || (
    modifiers & Schwarz && tricksValue < 120 ? Loss : (
      modifiers & Schneider && tricksValue < 90 ? Loss : (
        tricksValue <= 60 ? Loss : Win
      )
    )
  );

  var basePoints = valueMap[suit];
  var gameModifier = (
    jacks +
    1 +
    (modifiers & Hand ? 1 : 0) +
    (modifiers & Overt ? 1 : 0) +
    (modifiers & Schneider ? 1 : 0) +
    (modifiers & Schwarz ? 1 : 0) +
    (tricksValue === 120 ? 1 : 0) +
    (tricksValue >= 90 ? 1 : 0)
  );

  var points = (
    basePoints *
    gameModifier *
    (outcome === Win ? 1 : -2) *
    (modifiers & Contra ? 2 : 1) *
    (modifiers & Re ? 2 : 1) *
    (modifiers & Bock ? 2 : 1)
  );

  var merged = {}
  for (var k in result)
    merged[k] = result[k]
  merged.outcome = outcome
  merged.player = player
  merged.points = pointsDelta(players, player, points)
  return merged
}

/**
 * Calculate results based on game state.
 *
 * @param {Player[]} players
 * @param {Partial<State>} state
 *
 * @return {Result}
 */
function calculateResults(players, state) {

  var suit = state.game.suit;

  if (suit === Ramsch) {
    return calculateRamschResults(players, state);
  }

  if (suit === Null) {
    return calculateNullResults(players, state);
  }

  return calculateSuitResults(players, state);
}

/* ================================ Game.js ================================ */
/* global console */






/**
 * @typedef { import('./types').Card } Card
 * @typedef { import('./types').State } State
 * @typedef { import('./types').Result } Result
 * @typedef { import('./types').Player } Player
 * @typedef { import('./types').Suit } Suit
 *
 * @typedef { import('./types').GameStep } GameStep
 *
 * @typedef { {
 *   state: Partial<State>,
 *   initialStep: GameStep,
 *   expectedActor: Player
 * } } GameInit
 */

/**
 * @constructor
 * @param { { verbose?: boolean } } [options]
 * @param {GameInit} [init]
 */
function excludePlayer(list, player) {
  var out = []
  for (var i = 0; i < list.length; i++)
    if (list[i] !== player)
      out.push(list[i])
  return out
}

function Game(options, init) {

  var verbose = options && options.verbose || false;

  var players = [ 0, 1, 2 ];

  var state = init && init.state || {};

  var stateMachine = new StateMachine({
    steps: [
      [ 'initial', 'start', function () {
        return 'deal';
      } ],

      [ 'deal', function () {
        var dealt = dealCards();
        var hands = dealt[0];
        var skat = dealt[1];

        var initialHands = []
        for (var h = 0; h < hands.length; h++)
          initialHands.push(hands[h].slice())

        state.initialHands = initialHands
        state.initialSkat = skat.slice()
        state.hands = hands
        state.skat = skat

        return 'dealt';
      } ],

      [ 'dealt', function () {
        return 'bidding-start';
      } ],

      [ 'bidding-start', function () {

        var participants = players.slice();

        var bidder = participants[2];

        state.bidding = {
          bidder: bidder,
          acknowledger: participants[1],
          participants: participants,
          leader: null,
          bid: null
        };

        return [ 'ask-bid', bidder ];
      } ],

      [ 'ask-bid', 'bid', function (
          /** @type {Player} */ player,
          /** @type {number} */ playerBid
      ) {

        var bidding = state.bidding;

        var bid = bidding.bid;
        var acknowledger = bidding.acknowledger;

        if (Math.floor(playerBid) !== playerBid) {
          throw new Error('expected integral bid, found ' + playerBid);
        }

        var minBid = (bid ? bid : 18);

        // A fresh bid must beat the current one strictly; the opening bid
        // must be at least 18.
        if (bid ? playerBid <= bid : playerBid < 18) {
          throw new Error('expected bid ' + (bid ? '> ' + bid : '>= 18') + ', found ' + playerBid);
        }

        if (acknowledger) {
          bidding.leader = player;
          bidding.bid = playerBid;

          return [ 'ask-ack', acknowledger ];
        } else {
          bidding.leader = player;
          bidding.bid = playerBid;

          return 'bidding-completed';
        }
      } ],

      [ 'ask-bid', 'pass', function (/** @type {Player} */ player) {

        var bidding = state.bidding;

        var bid = bidding.bid;
        var leader = bidding.leader;

        var participants = excludePlayer(bidding.participants, player);

        // everyone passed _or_
        // last player remaining is leader
        if (
          (participants.length === 0) ||
          (participants.length === 1 && leader)
        ) {
          bidding.leader = leader;
          bidding.bid = bid;

          return 'bidding-completed';
        }

        // player(s) remaining, swap bidder / acknowledger

        var bidder = participants[0];
        var acknowledger = null;
        for (var i = 0; i < participants.length; i++)
          if (participants[i] !== bidder) {
            acknowledger = participants[i];
            break;
          }

        bidding.participants = participants;
        bidding.bidder = bidder;
        bidding.acknowledger = acknowledger;

        return [ 'ask-bid', bidder ];
      } ],

      [ 'ask-ack', 'ack', function (/** @type {Player} */ player) {

        var bidding = state.bidding;

        var bidder = bidding.bidder;

        bidding.leader = player;

        return [ 'ask-bid', bidder ];
      } ],

      [ 'ask-ack', 'pass', function (/** @type {Player} */ player) {

        var bidding = state.bidding;

        var bid = bidding.bid;
        var leader = bidding.leader;

        var participants = excludePlayer(bidding.participants, player);

        // bidder wins
        if (participants.length === 1) {
          bidding.leader = leader;
          bidding.bid = bid;

          return 'bidding-completed';
        }

        var bidder = participants[0];
        var acknowledger = bidding.bidder;

        bidding.participants = participants;
        bidding.bidder = bidder;
        bidding.acknowledger = acknowledger;

        return [ 'ask-bid', bidder ];
      } ],

      [ 'bidding-completed', function () {

        var bidding = state.bidding;

        var leader = bidding.leader;

        state.game = {
          modifiers: Hand
        };
        state.player = leader;

        return [ 'ask-declare', leader ];
      } ],

      [ 'ask-declare', 'pick-skat', function (/** @type {Player} */ player) {

        var skat = state.skat;
        var hands = state.hands;
        var game = state.game;

        var updatedHands = hands.slice();

        updatedHands[player] = updatedHands[player].concat(skat);

        game.modifiers = game.modifiers & ~Hand;
        state.hands = updatedHands;

        return [ 'ask-skat', player ];
      } ],

      [ 'ask-skat', 'put-skat', function (
          /** @type {Player} */ player,
          /** @type {Card[]} */ skat
      ) {

        var hands = state.hands;

        if (skat.length !== 2) {
          throw new Error('must put two cards to skat');
        }

        var updatedHands = hands.slice();

        var playerHand = updatedHands[player];

        for (var i = 0; i < skat.length; i++)
          if (playerHand.indexOf(skat[i]) === -1) {
            throw new Error('cannot drop what is not on your hand');
          }

        var newHand = []
        for (var j = 0; j < playerHand.length; j++)
          if (skat.indexOf(playerHand[j]) === -1) {
            newHand.push(playerHand[j]);
          }

        updatedHands[player] = newHand;

        state.hands = updatedHands;
        state.skat = skat;

        return [ 'ask-declare', player ];
      } ],

      [ 'ask-declare', 'declare', function (
          /** @type {Player} */ player,
          /** @type { { suit: Suit, modifiers?: number } } */ declaration
      ) {

        var game = state.game;
        var hands = state.hands;
        var skat = state.skat;

        var suit = declaration.suit;

        if (AllSuits.indexOf(suit) === -1) {
          throw new Error('unknown suit <' + suit + '>');
        }

        var declarationModifiers = declaration.modifiers || 0;

        if (declarationModifiers & Hand) {
          throw new Error('cannot declare Hand');
        }

        if (suit === Null) {
          if (declarationModifiers & Schneider) {
            throw new Error('illegal modifier <Schneider> for suit <Null>');
          }

          if (declarationModifiers & Schwarz) {
            throw new Error('illegal modifier <Schwarz> for suit <Null>');
          }
        }

        var gameModifiers = game.modifiers || 0;

        // Ouvert implies Schwarz (rules: "Schwarz has to be announced in
        // order to declare Ouvert"), and Schwarz implies Schneider.
        if (declarationModifiers & Overt) {
          declarationModifiers = declarationModifiers | (Schwarz | Schneider);
        }

        // Schwarz implies Schneider
        if (declarationModifiers & Schwarz) {
          declarationModifiers = declarationModifiers | Schneider;
        }

        var modifiers = declarationModifiers | gameModifiers;

        game.modifiers = modifiers;
        game.suit = suit;
        if (suit !== Null) {
          game.jacks = getJacksModifier(hands[player].concat(skat));
        }

        return 'declared';
      } ],

      [ 'declared', function () {
        return 'game-start';
      } ],

      [ 'game-start', function () {

        var playerTricks = []
        for (var p = 0; p < players.length; p++)
          playerTricks.push([])

        state.playerTricks = playerTricks;
        state.currentTrick = [];
        state.lastTrick = null;
        state.tricks = [];

        return [ 'ask-card', players[1] ];
      } ],

      [ 'ask-card', 'play-card', function (
          /** @type { Player } */ player,
          /** @type { Card } */ card
      ) {

        var suit = state.game.suit;

        var hand = state.hands[player];

        if (hand.indexOf(card) === -1) {
          throw new Error('card <' + card + '> not in <' + player + '> hand');
        }

        if (!isValidTrickCard(card, state.currentTrick, hand, suit)) {
          throw new Error('invalid card <' + card + '> in current trick');
        }

        // remove card from hand
        var newHand = []
        for (var i = 0; i < hand.length; i++)
          if (hand[i] !== card) {
            newHand.push(hand[i]);
          }

        state.hands[player] = newHand;
        state.currentTrick = state.currentTrick.concat([ [ player, card ] ]);

        if (state.currentTrick.length === 3) {
          return 'trick-complete';
        }

        return [ 'ask-card', (player + 1) % players.length ];
      } ],

      [ 'trick-complete', function () {

        var currentTrick = state.currentTrick;
        var player = state.player;

        var suit = state.game.suit;

        var winner = getTrickWinner(currentTrick, state.game.suit);

        var tricks = state.tricks.concat([ currentTrick ]);
        var playerTricks = state.playerTricks.slice();
        if (player === winner) {
          playerTricks[player] = playerTricks[player].concat(currentTrick);
        }

        state.tricks = tricks;
        state.playerTricks = playerTricks;
        state.currentTrick = [];
        state.lastTrick = currentTrick;

        // Null player took trick
        if (suit === Null && player === winner) {
          return 'game-finish';
        }

        if (tricks.length === 10) {
          return 'game-finish';
        }

        return [ 'ask-card', winner ];
      } ],

      [ 'ask-card', 'give-up', function (/** @type {Player} */ player) {

        var _player = state.player;
        var game = state.game;

        if (game.suit === Ramsch) {
          throw new Error('cannot give up a game of Ramsch');
        }

        state.result = {
          player: _player,
          outcome: player === _player ? Loss : Win,
          reason: [ player, 'give-up' ]
        };

        return 'game-finish';
      } ],

      [ 'game-finish', function () {

        state.result = calculateResults(players, state);

        verbose && console.log('GAME game-finish', state.player, state.result, state.result.points);

        return 'end';
      } ],

      [ 'end' ]
    ],
    verbose: verbose
  });


  // API ///////////////////////

  /**
   * @param { [ step: GameStep ] | [ step: GameStep, player: Player, ...unknown[] ] } args
   *
   * @return { [ step: GameStep, actor: Player | null ] }
   */
  this.next = function() {

    var args = Array.prototype.slice.call(arguments);

    // @ts-ignore-error
    var result = stateMachine.next.apply(stateMachine, args);

    var next = result[0];
    var actor = result[1];

    verbose && console.log('req ' + next + ' <' + (typeof actor !== 'undefined' ? actor : 'null') + '>');

    return result;
  };

  // expose state //////////////

  /**
   * @type { Partial<State> }
   */
  this.state = state;

  Object.defineProperty(this, 'state', {
    get: function () { return state; }
  });

  // API ////////////////////////

  /**
   * Return the game result after it completed.
   *
   * @return {Partial<Result>}
   */
  this.getResult = function() {
    return state.result;
  };
}

/* ================================ Automa.js ================================ */
/**
 * @typedef { import('./types').Player } Player
 * @typedef { import('./types').Card } Card
 * @typedef { import('./types').Suit } Suit
 *
 * @typedef { import('./types').GameState } GameState
 * @typedef { import('./types').GameStep } GameStep
 *
 * @typedef { import('./Game').default } Game
 */

/* eslint "no-constant-condition": Off */



var BIDS = [ 18, 20, 22, 23, 24, 27, 30, 33, 35, 36, 40, 44, 45, 46, 48, 50,
             54, 55, 59, 60, 63, 66, 70, 72, 77, 80, 81, 84, 88, 90, 96, 99 ];

/**
 * @type { Record<import('./types').Picture, number> }
 */
var NULL_GAME_CARD_VALUES = {
  'A': -2,
  'K': -2,
  'Q': -2,
  'J': 0,
  '10': 0,
  '9': 1,
  '8': 1,
  '7': 2
};

/**
 * @type { Record<import('./types').Picture, number> }
 */
var COLOR_GAME_CARD_VALUES = {
  'A': 5,
  '10': 3,
  'K': 2,
  'Q': 2,
  'J': 7,
  '9': 1,
  '8': 1,
  '7': 1
};


/**
 * @constructor
 */
function Automa() {

  var pickedSkat = false;

  /**
   * @param { Game } game
   * @param { GameStep } step
   * @param { Player } player
   * @param { ...unknown } args
   *
   * @return { [ GameStep, ...unknown[] ] } next step
   */
  this.next = function(game, step, player) {

    switch (step) {
    case 'ask-declare': {

      var result = evaluateHand(game.state.hands[player]);

      if (result.modifiers & Hand || pickedSkat) {
        return [ 'declare', {
          suit: result.suit,
          modifiers: result.modifiers & ~Hand
        } ];
      }

      pickedSkat = true;

      return [ 'pick-skat' ];
    }

    case 'ask-skat': {

      var hand = game.state.hands[player];

      var result = evaluateHand(hand);

      var skat = dropSkat(hand, result.suit);

      return [ 'put-skat', skat ];
    }

    case 'ask-card': {

      var suit = game.state.game.suit;

      var currentTrick = game.state.currentTrick;
      var hand = game.state.hands[player];

      while (true) {
        var card = randomElement(hand);

        if (isValidTrickCard(card, currentTrick, hand, suit)) {
          return [ 'play-card', card ];
        }
      }
    }

    case 'ask-ack': {
      var bid = game.state.bidding.bid;

      var value = evaluateHand(game.state.hands[player]).value;

      if (value >= bid) {
        return [ 'ack' ];
      }

      return [ 'pass' ];
    }

    case 'ask-bid': {
      var bid = game.state.bidding.bid || 17;

      var value = evaluateHand(game.state.hands[player]).value;

      var nextBid = increaseBid(bid, BIDS);

      if (value >= nextBid) {
        return [ 'bid', nextBid ];
      }

      return [ 'pass' ];
    }
    }
  };

}



// helpers ////////////

/**
 * @param {Card[]} hand
 *
 * @return { {
 *   modifiers: import('./types').GameModifiers,
 *   suit: import('./types').Suit,
 *   value: number
 * } }
 */
function evaluateHand(hand) {

  var nullValue = 0;
  var i, card, components;
  for (i = 0; i < hand.length; i++) {
    card = hand[i];
    components = cardComponents(card);
    nullValue += NULL_GAME_CARD_VALUES[components[1]];
  }

  // let's play Null
  if (nullValue > 3) {
    return {
      modifiers: nullValue > 6 ? Hand : NoModifiers,
      suit: Null,
      value: nullValue > 6 ? 35 : 23
    };
  }

  var trumps = [];
  var c, j, suit, cards, cardsValue;
  for (c = 0; c < ColorSuits.length; c++) {
    suit = ColorSuits[c];
    cards = [];
    cardsValue = 0;
    for (j = 0; j < hand.length; j++) {
      card = hand[j];
      if (TRUMP_ORDER[suit][card]) {
        cards.push(card);
        components = cardComponents(card);
        cardsValue += COLOR_GAME_CARD_VALUES[components[1]];
      }
    }
    trumps.push({
      suit: suit,
      cards: cards,
      cardsValue: cardsValue
    });
  }

  var sortedTrumps = trumps.sort(function(a, b) { return b.cards.length - a.cards.length; });

  suit = sortedTrumps[0].suit;
  cards = sortedTrumps[0].cards;
  cardsValue = sortedTrumps[0].cardsValue;

  // won't play shaky games
  if (cards.length < 5 || cardsValue < 12) {
    return {
      modifiers: NoModifiers,
      value: -1,
      suit: suit
    };
  }

  var values = {};
  values[Grand] = 48;
  values[Spades] = 22;
  values[Clubs] = 24;
  values[Hearts] = 20;
  values[Diamonds] = 18;

  return {
    modifiers: NoModifiers,
    suit: suit,
    value: values[suit]
  };

}

/**
 * @param { Card[] } hand
 * @param { Suit } suit
 *
 * @return { [ Card, Card ] }
 */
function dropSkat(hand, suit) {
  var skat = [];

  var trumps = TRUMP_ORDER[suit];

  while (skat.length < 2) {

    var card = randomElement(hand);

    // do not drop low value cards
    if (suit === Null && !CardValues[card]) {
      continue;
    }

    // do not drop trump
    if (!trumps[card]) {
      skat.push(card);
    }
  }

  return skat;
}

/**
 * @param {number} bid
 * @param {number[]} bids
 *
 * @return {number}
 */
function increaseBid(bid, bids) {
  var i;
  for (i = 0; i < bids.length; i++) {
    if (bids[i] > bid) {
      return bids[i];
    }
  }
  return bid + 5;
}

/**
 * @template T
 *
 * @param {T[]} arr
 *
 * @return {T}
 */
function randomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

/*
 * sailfish-cards card ids are suit * 13 + rank - 1, where rank runs from
 * 1 (A) to 13 (K) and the suits are 0 Clubs, 1 Diamonds, 2 Hearts,
 * 3 Spades. Skat only uses the ranks 7, 8, 9, 10, J, Q, K and A.
 */

var _suitIndex = {}
_suitIndex[Clubs]    = 0
_suitIndex[Diamonds] = 1
_suitIndex[Hearts]   = 2
_suitIndex[Spades]   = 3

var _suitSymbol = [ Clubs, Diamonds, Hearts, Spades ]

var _rankNumber = {}
_rankNumber[Seven] = 7
_rankNumber[Eight] = 8
_rankNumber[Nine]  = 9
_rankNumber[Ten]   = 10
_rankNumber[Jack]  = 11
_rankNumber[Queen] = 12
_rankNumber[King]  = 13
_rankNumber[Ace]   = 1

var _rankText = {}
_rankText[1]  = Ace
_rankText[7]  = Seven
_rankText[8]  = Eight
_rankText[9]  = Nine
_rankText[10] = Ten
_rankText[11] = Jack
_rankText[12] = Queen
_rankText[13] = King

function toCardId(card) {
  return _suitIndex[card.charAt(0)] * 13 + _rankNumber[card.substring(1)] - 1
}

function fromCardId(id) {
  return _suitSymbol[Math.floor(id / 13)] + _rankText[id % 13 + 1]
}

var skatCardIds = []
for (var _suit = 0; _suit < 4; ++_suit) {
  for (var _rank = 1; _rank <= 13; ++_rank) {
    if (_rank === 1 || _rank >= 7)
      skatCardIds.push(_suit * 13 + _rank - 1)
  }
}

/* =============================== QML surface ============================= */

var Constants = {
  Seven: Seven, Eight: Eight, Nine: Nine, Ten: Ten,
  Jack: Jack, Queen: Queen, King: King, Ace: Ace,
  Grand: Grand, Null: Null, Ramsch: Ramsch,
  Clubs: Clubs, Spades: Spades, Hearts: Hearts, Diamonds: Diamonds,
  Schneider: Schneider, Schwarz: Schwarz, Contra: Contra,
  Re: Re, Bock: Bock, Overt: Overt, Hand: Hand,
  NoModifiers: NoModifiers, AllModifiers: AllModifiers,
  Win: Win, Loss: Loss,
  ColorSuits: ColorSuits, Pictures: Pictures, PictureValues: PictureValues,
  AllCards: AllCards, CardComponents: CardComponents,
  CardValues: CardValues, AllSuits: AllSuits
}

var Util = {
  SUIT_ORDER: SUIT_ORDER, TRUMP_ORDER: TRUMP_ORDER, COLOR_ORDER: COLOR_ORDER,
  getCardValue: getCardValue, cardComponents: cardComponents,
  findCard: findCard, getTrickWinner: getTrickWinner,
  isValidTrickCard: isValidTrickCard, beatsCompare: beatsCompare,
  semanticCompare: semanticCompare, semanticSort: semanticSort,
  getJacksModifier: getJacksModifier, dealCards: dealCards,
  shuffle: shuffle
}

var Results = {
  calculateResults: calculateResults
}

var Skaat = {
  Constants: Constants,
  Util: Util,
  Results: Results,
  StateMachine: StateMachine,
  Game: Game,
  Automa: Automa,
  toCardId: toCardId,
  fromCardId: fromCardId,
  skatCardIds: skatCardIds,
  /* bidding ladder per rules.txt */
  BIDS: [18, 20, 22, 23, 24, 27, 30, 33, 35, 36, 40, 44, 45, 46, 48, 50,
         54, 55, 59, 60, 63, 66, 70, 72, 77, 80, 81, 84, 88, 90, 96, 99]
}

/* ================================ self test ============================== */
/*
 * Runs a sample of the skaat test-suite assertions plus simulated
 * all-bot and forced-declaration games. Returns null on success or an
 * error message on failure.
 */

/*
 * Contract per skaat's own test-suite (test/Util.spec.js):
 * scan ColorSuits order (Clubs, Spades, Hearts, Diamonds) and count
 * the leading run of identical jack presence; a status flip stops it.
 */
function _selfTestJacksModifier() {
  var m = Util.getJacksModifier
  if (m(['♣J', '♦J']) !== 1)                       throw new Error('jacks modifier (♣♦)')
  if (m(['♣J', '♠J', '♦J']) !== 2)                 throw new Error('jacks modifier (♣♠♦)')
  if (m(['♣J', '♠J', '♥J', '♦J']) !== 4)           throw new Error('jacks modifier (all)')
  if (m(['♦J']) !== 3)                             throw new Error('jacks modifier (♦)')
  if (m(['♠J', '♦J']) !== 1)                       throw new Error('jacks modifier (♠♦)')
  if (m(['♥J']) !== 2)                             throw new Error('jacks modifier (♥)')
}

function _selfTestDeal() {
  var d = Util.dealCards()
  if (d.length !== 2) throw new Error('dealCards shape')
  var hands = d[0], skat = d[1]
  if (hands.length !== 3 || skat.length !== 2) throw new Error('dealCards size')
  for (var i = 0; i < 3; ++i)
    if (hands[i].length !== 10) throw new Error('dealCards hand size')
  var seen = {}
  for (var h = 0; h < 3; ++h)
    for (var c = 0; c < hands[h].length; ++c)
      if (seen[hands[h][c]]) throw new Error('dealCards duplicate')
      else seen[hands[h][c]] = true
  for (var s = 0; s < skat.length; ++s)
    if (seen[skat[s]]) throw new Error('dealCards skat duplicate')
    else seen[skat[s]] = true
  if (Object.keys(seen).length !== 32) throw new Error('dealCards card count')
}

function _selfTestTricks() {
  if (Util.beatsCompare('♥J', '♣J', Null) !== -1) throw new Error('beatsCompare jack under null')
  if (Util.beatsCompare('♥7', '♥10', Null) !== -3) throw new Error('beatsCompare null suit order')
  if (Util.beatsCompare('♥Q', '♥10', Null) !== 2) throw new Error('beatsCompare null pictures')
  // lead is trump: must follow trump if one is held
  if (!Util.isValidTrickCard('♠A', [[ 0, '♠7' ]], ['♠A', '♥7'], Spades))
    throw new Error('isValidTrickCard trump follow')
  if (Util.isValidTrickCard('♥7', [[ 0, '♠7' ]], ['♥7', '♠9'], Spades))
    throw new Error('isValidTrickCard trump follow (negative)')
  if (!Util.isValidTrickCard('♣9', [[ 0, '♠7' ]], ['♥7', '♣9'], Spades))
    throw new Error('isValidTrickCard no trumps left')
  // lead is not trump: must follow suit if one is held
  if (!Util.isValidTrickCard('♥9', [[ 0, '♥7' ]], ['♥9', '♣7'], Clubs))
    throw new Error('isValidTrickCard suit follow')
  if (Util.isValidTrickCard('♦9', [[ 0, '♥7' ]], ['♦9', '♥8'], Clubs))
    throw new Error('isValidTrickCard suit follow (negative)')
  if (!Util.isValidTrickCard('♦9', [[ 0, '♥7' ]], ['♦9', '♣7'], Clubs))
    throw new Error('isValidTrickCard no suits left')
}

function _selfTestAdapter() {
  if (toCardId('♣7') !== 6)   throw new Error('toCardId ♣7')
  if (toCardId('♦J') !== 23)  throw new Error('toCardId ♦J')
  if (toCardId('♥A') !== 26)  throw new Error('toCardId ♥A')
  if (toCardId('♠10') !== 48) throw new Error('toCardId ♠10')
  if (skatCardIds.length !== 32) throw new Error('skatCardIds length')
  for (var i = 0; i < skatCardIds.length; ++i) {
    var id = skatCardIds[i]
    var card = fromCardId(id)
    if (toCardId(card) !== id) throw new Error('card id round trip ' + id)
  }
}

/*
 * Drive an all-bot game to completion. The state machine is pulled by
 * game.next(step, player, ...args) and returns [ state, actor ].
 */
function _playAllBotGame() {
  var game = new Game()
  var bots = [ new Automa(), new Automa(), new Automa() ]
  var result = game.next('start')
  var guard = 0
  while (result[0] !== 'end' && guard++ < 500) {
    var step = result[0]
    var player = result[1]
    /* everyone passed the bidding; upstream AutomaSpec counts this as a pass */
    if (step === 'ask-declare' && player === null)
      return null
    var r = bots[player].next(game, step, player)
    var call = [ r[0], player ]
    for (var i = 1; i < r.length; ++i) call.push(r[i])
    result = game.next.apply(game, call)
  }
  if (result[0] !== 'end') throw new Error('all-bot game did not finish')
  var res = game.getResult()
  if (!res || (res.outcome !== Win && res.outcome !== Loss))
    throw new Error('all-bot game result')
  if (!Array.isArray(res.points) || res.points.length !== 3)
    throw new Error('all-bot game result points')
}

/*
 * Force a particular declaration. A Hand game is requested by
 * declaring without picking the skat (the engine clears the Hand
 * modifier on pick-skat); otherwise the skat is picked first.
 */
function _playForcedGame(suit, modifiers, handGame) {
  var game = new Game()
  var bots = [ new Automa(), new Automa(), new Automa() ]
  var result = game.next('start')
  var guard = 0
  while (result[0] !== 'ask-declare' && guard++ < 50) {
    var step = result[0]
    var player = result[1]
    if (step === 'ask-bid') {
      var current = game.state.bidding.bid || 0;
      result = game.next('bid', player, increaseBid(current, BIDS))
    } else if (step === 'ask-ack') {
      result = game.next('pass', player)
    } else {
      throw new Error('forced: unexpected step ' + step)
    }
  }
  if (result[0] !== 'ask-declare') throw new Error('forced: no declare phase')
  var leader = result[1]
  if (!handGame) {
    result = game.next('pick-skat', leader)
    var hand = game.state.hands[leader]
    result = game.next('put-skat', leader, [ hand[0], hand[1] ])
  }
  result = game.next('declare', leader, { suit: suit, modifiers: modifiers })
  guard = 0
  while (result[0] !== 'end' && guard++ < 500) {
    step = result[0]
    player = result[1]
    var r = bots[player].next(game, step, player)
    var call = [ r[0], player ]
    for (var i = 1; i < r.length; ++i) call.push(r[i])
    result = game.next.apply(game, call)
  }
  if (result[0] !== 'end') throw new Error('forced game did not finish (' + suit + ')')
  if (!game.getResult()) throw new Error('forced game has no result (' + suit + ')')
}

function selfTest() {
  try {
    _selfTestJacksModifier()
    _selfTestDeal()
    _selfTestTricks()
    _selfTestAdapter()
    for (var i = 0; i < 300; ++i)
      _playAllBotGame()
    _playForcedGame(Clubs, NoModifiers, false)
    _playForcedGame(Spades, NoModifiers, false)
    _playForcedGame(Hearts, NoModifiers, false)
    _playForcedGame(Diamonds, NoModifiers, false)
    _playForcedGame(Grand, NoModifiers, false)
    _playForcedGame(Null, NoModifiers, false)
    _playForcedGame(Null, NoModifiers, true)
    _playForcedGame(Clubs, NoModifiers, true)
    _playForcedGame(Ramsch, NoModifiers, false)
    _playForcedGame(Clubs, Schneider, false)
    _playForcedGame(Clubs, Schwarz, false)
  } catch (err) {
    return String(err && err.message || err)
  }
  return null
}
