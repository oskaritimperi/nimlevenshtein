## A module for fast computation of
##
## - Levenshtein (edit) distance and edit sequence manipulation
## - string similarity
## - approximate median strings, and generally string averaging
## - string sequence and set similarity
##
## This module uses the standalone version C API of the python-Levenshtein library. So no Python
## required.
##
## The API reflects the API of the python-Levenshtein library. If you want to have a lower level
## interface, you can import ``nimlevenshtein/wrapper``, which gives you nimified wrapper functions
## over the C API functions. And if you want to go more lower level, you can use
## ``nimlevenshtein/binding``.

import nimlevenshtein/wrapper

export EditOp
export OpCode
export EditType
export MatchingBlock

proc distance*(a, b: string): int =
    ## Compute absolute Levenshtein distance of two strings.
    runnableExamples:
        assert distance("Levenshtein", "Lenvinsten") == 4
        assert distance("Levenshtein", "Levensthein") == 2
        assert distance("Levenshtein", "Levenshten") == 1
        assert distance("Levenshtein", "Levenshtein") == 0
    distance(a, b, 0)

proc ratio*(a, b: string): float =
    ## Compute similarity of two strings.
    ##
    ## The similarity is a number between 0 and 1, it's usually equal or somewhat higher than
    ## Python's ``difflib.SequenceMatcher.ratio()``, because it's based on real minimal edit
    ## distance.
    runnableExamples:
        from math import round
        assert round(ratio("Hello world!", "Holly grail!"), 4) == 0.5833
        assert ratio("Brian", "Jesus") == 0.0
    let lensum = len(a) + len(b)
    if lensum == 0:
        return 1.0
    let ldist = distance(a, b, 1)
    result = (lensum - ldist).float / lensum.float

proc hamming*(a, b: string): int =
    ## Compute Hamming distance of two strings.
    ##
    ## The Hamming distance is simply the number of differing characters. That means the length of
    ## the strings must be the same.
    runnableExamples:
        assert hamming("Hello world!", "Holly grail!") == 7
        assert hamming("Brian", "Jesus") == 5
    if len(a) != len(b):
        raise newException(Exception, "expected two strings of the same length")
    hammingDistance(a, b)

proc jaro*(a, b: string): float =
    ## Compute Jaro string similarity metric of two strings.
    ##
    ## The Jaro string similarity metric is intended for short strings like personal last names. It
    ## is 0 for completely different strings and 1 for identical strings.
    runnableExamples:
        from math import round
        assert jaro("Brian", "Jesus") == 0.0
        assert round(jaro("Thorkel", "Thorgier"), 4) == 0.7798
        assert round(jaro("Dinsdale", "D"), 4) == 0.7083
    jaroRatio(a, b)

proc jaroWinkler*(a, b: string, prefixWeight: float = 0.1): float =
    ## Compute Jaro string similarity metric of two strings.
    ##
    ## The Jaro-Winkler string similarity metric is a modification of Jaro metric giving more weight
    ## to common prefix, as spelling mistakes are more likely to occur near ends of words.
    ##
    ## The prefix weight is inverse value of common prefix length sufficient to consider the strings
    ## *identical*. If no prefix weight is specified, 1/10 is used.
    runnableExamples:
        from math import round
        assert jaroWinkler("Brian", "Jesus") == 0.0
        assert round(jaroWinkler("Thorkel", "Thorgier"), 4) == 0.8679
        assert round(jaroWinkler("Dinsdale", "D"), 4) == 0.7375
        assert jaroWinkler("Thorkel", "Thorgier", 0.25) == 1.0
    if prefixWeight < 0:
        raise newException(Exception, "negative prefix weight")
    jaroWinklerRatio(a, b, prefixWeight)

template medianCommon(f: typed, strings: seq[string], weights: seq[float] = @[]): string =
    if len(strings) == 0:
        return ""

    var wl = weights
    if len(wl) == 0:
        setLen(wl, len(strings))
        for i in 0..<len(wl):
            wl[i] = 1.0
    else:
        if len(strings) != len(weights):
            raise newException(Exception, "expected same amount of strings and weights")

    f(strings, wl)

proc median*(strings: seq[string], weights: seq[float] = @[]): string =
    ## Find an approximate generalized median string using greedy algorithm.
    ##
    ## You can optionally pass a weight for each string as the second argument. The weights are
    ## interpreted as item multiplicities, although any non-negative real numbers are accepted. Use
    ## them to improve computation speed when strings often appear multiple times in the sequence.
    runnableExamples:
        assert median(@["SpSm", "mpamm", "Spam", "Spa", "Sua", "hSam"]) == "Spam"
        let fixme = @["Levnhtein", "Leveshein", "Leenshten",
                      "Leveshtei", "Lenshtein", "Lvenstein",
                      "Levenhtin", "evenshtei"]
        assert median(fixme) == "Levenshtein"
    medianCommon(greedyMedian, strings, weights)

proc medianImprove*(s: string, strings: seq[string], weights: seq[float] = @[]): string =
    ## Improve an approximate generalized median string by perturbations.
    ##
    ## The first argument is the estimated generalized median string you want to improve, the others
    ## are the same as in `median()`. It returns a string with total distance less or equal to that
    ## of the given string.
    ##
    ## Note this is much slower than `median()`. Also note it performs only one improvement step,
    ## calling `medianImprove()` again on the result may improve it further, though this is unlikely
    ## to happen unless the given string was not very similar to the actual generalized median.
    runnableExamples:
        let fixme = @["Levnhtein", "Leveshein", "Leenshten",
                      "Leveshtei", "Lenshtein", "Lvenstein",
                      "Levenhtin", "evenshtei"]
        assert medianImprove("spam", fixme) == "enhtein"
        assert medianImprove(medianImprove("spam", fixme), fixme) == "Levenshtein"
    if len(strings) == 0:
        return ""

    var wl = weights
    if len(wl) == 0:
        setLen(wl, len(strings))
        for i in 0..<len(wl):
            wl[i] = 1.0
    else:
        if len(strings) != len(weights):
            raise newException(Exception, "expected same amount of strings and weights")

    wrapper.medianImprove(s, strings, wl)

proc quickmedian*(strings: seq[string], weights: seq[float] = @[]): string =
    ## Find a very approximate generalized median string, but fast.
    ##
    ## See `median()` for argument description.
    ##
    ## This method is somewhere between `setmedian()` and picking a random string from the set; both
    ## speedwise and quality-wise.
    runnableExamples:
        let fixme = @["Levnhtein", "Leveshein", "Leenshten",
                      "Leveshtei", "Lenshtein", "Lvenstein",
                      "Levenhtin", "evenshtei"]
        assert quickmedian(fixme) == "Levnshein"
    medianCommon(wrapper.quickMedian, strings, weights)

proc setmedian*(strings: seq[string], weights: seq[float] = @[]): string =
    ## Find set median of a string set (passed as a sequence).
    ##
    ## See `median()` for argument description.
    ##
    ## The returned string is always one of the strings in the sequence.
    runnableExamples:
        assert setmedian(@["ehee", "cceaes", "chees", "chreesc",
                           "chees", "cheesee", "cseese", "chetese"]) == "chees"
    medianCommon(wrapper.setMedian, strings, weights)

template setSeqCommon(f: typed, a: seq[string], b: seq[string]): float =
    let lensum = len(a) + len(b)

    if lensum == 0:
        return 1.0

    if len(a) == 0 or len(b) == 0:
        return 0.0

    let r = f(a, b)

    if r < 0.0:
        raise newException(Exception, "failed")

    (lensum.float - r) / lensum.float

proc seqratio*(a: seq[string], b: seq[string]): float =
    ## Compute similarity ratio of two sequences of strings.
    ##
    ## This is like `ratio()`, but for string sequences. A kind of `ratio()` is used to to measure
    ## the cost of item change operation for the strings.
    runnableExamples:
        from math import round
        assert round(seqratio(@["newspaper", "litter bin", "tinny", "antelope"],
            @["caribou", "sausage", "gorn", "woody"]), 4) == 0.2152
        assert seqratio(@[], @["foobar"]) == 0.0
        assert seqratio(@["foobar"], @[]) == 0.0
    setSeqCommon(editSeqDistance, a, b)

proc setratio*(a: seq[string], b: seq[string]): float =
    ## Compute similarity ratio of two strings sets (passed as sequences).
    ##
    ## The best match between any strings in the first set and the second set (passed as sequences)
    ## is attempted. I.e., the order doesn't matter here.
    runnableExamples:
        from math import round
        assert round(setratio(@["newspaper", "litter bin", "tinny", "antelope"],
            @["caribou", "sausage", "gorn", "woody"]), 4) == 0.2818
        assert setratio(@[], @["foobar"]) == 0.0
        assert setratio(@["foobar"], @[]) == 0.0
    setSeqCommon(setDistance, a, b)

proc editops*(string1: string, string2: string): seq[EditOp] =
    ## Find sequence of edit operations transforming one string to another.
    ##
    ## The result is a sequence of `EditOp` objects. These are operations on single characters.
    ## In fact the returned sequence doesn't contain the *equal*, but all the related functions
    ## accept both lists with and without *equals*.
    runnableExamples:
        let ops = editops("spam", "park")
        assert ops[0] == EditOp(`type`: EditType.Delete, spos: 0, dpos: 0)
        assert ops[1] == EditOp(`type`: EditType.Insert, spos: 3, dpos: 2)
        assert ops[2] == EditOp(`type`: EditType.Replace, spos: 3, dpos: 3)
    wrapper.editops(string1, string2)

proc editops*(ops: seq[OpCode], aLen: int, bLen: int): seq[EditOp] =
    ## Can be used for conversion from `OpCode` to `EditOp`. You can either pass in strings or
    ## their lengths, the result is the same.
    checkErrors(aLen, bLen, ops)
    toEditOps(ops, false)

proc editops*(ops: seq[OpCode], a: string, b: string): seq[EditOp] =
    ## Can be used for conversion from `OpCode` to `EditOp`. You can either pass in strings or
    ## their lengths, the result is the same.
    editops(ops, len(a), len(b))

proc opcodes*(a, b: string): seq[OpCode] =
    ## Find sequence of edit operations transforming one string to another.
    ##
    ## The result is a sequence of `OpCode` objects.
    runnableExamples:
        let ops = opcodes("spam", "park")
        assert ops[0] == OpCode(`type`: EditType.Delete, sbeg: 0, send: 1, dbeg: 0, dend: 0)
        assert ops[1] == OpCode(`type`: EditType.Keep, sbeg: 1, send: 3, dbeg: 0, dend: 2)
        assert ops[2] == OpCode(`type`: EditType.Insert, sbeg: 3, send: 3, dbeg: 2, dend: 3)
        assert ops[3] == OpCode(`type`: EditType.Replace, sbeg: 3, send: 4, dbeg: 3, dend: 4)
    editops(a, b).toOpCodes(len(a), len(b))

proc opcodes*(ops: seq[EditOp], aLen: int, bLen: int): seq[OpCode] =
    ## Can be used for conversion from `EditOp` to `OpCode`. You can either pass in strings or
    ## their lengths, the result is the same.
    checkErrors(aLen, bLen, ops)
    ops.toOpCodes(aLen, bLen)

proc opcodes*(ops: seq[EditOp], a: string, b: string): seq[OpCode] =
    ## Can be used for conversion from `EditOp` to `OpCode`. You can either pass in strings or
    ## their lengths, the result is the same.
    opcodes(ops, len(a), len(b))

proc inverse*(ops: seq[EditOp]): seq[EditOp] =
    ## Invert the sense of an edit operation sequence.
    ##
    ## In other words, it returns a sequence of edit operations transforming the second
    ## (destination) string to the first (source). It can be used with both editops and opcodes.
    runnableExamples:
        let inv = inverse(editops("spam", "park"))
        assert inv[0] == EditOp(`type`: EditType.Insert, spos: 0, dpos: 0)
        assert inv[1] == EditOp(`type`: EditType.Delete, spos: 2, dpos: 3)
        assert inv[2] == EditOp(`type`: EditType.Replace, spos: 3, dpos: 3)
        assert editops("park", "spam") == inv
    result = ops
    result.invert()

proc inverse*(ops: seq[OpCode]): seq[OpCode] =
    ## Invert the sense of an edit operation sequence.
    ##
    ## In other words, it returns a sequence of edit operations transforming the second
    ## (destination) string to the first (source). It can be used with both editops and opcodes.
    result = ops
    result.invert()

proc applyEdit*(ops: seq[EditOp], a: string, b:string): string =
    ## Apply a sequence of edit operations to a string.
    ##
    ## In the case of editops, the sequence can be arbitrary ordered subset of the edit sequence
    ## transforming source string to destination string.
    runnableExamples:
        let ops = editops("man", "scotsman")
        assert applyEdit(ops, "man", "scotsman") == "scotsman"
        assert applyEdit(ops[0..2], "man", "scotsman") == "scoman"
    if len(ops) == 0:
        return a
    checkErrors(len(a), len(b), ops)
    apply(a, b, ops)

proc applyEdit*(ops: seq[OpCode], a: string, b:string): string =
    if len(ops) == 0:
        return a
    checkErrors(len(a), len(b), ops)
    apply(a, b, ops)

template matchingBlocksCommon(ops: typed, aLen: int, bLen: int) =
    checkErrors(aLen, bLen, ops)
    result = matchingBlocks(aLen, bLen, ops)
    result.add(MatchingBlock(spos: aLen, dpos: bLen, len: 0))

proc matchingBlocks*(ops: seq[EditOp], aLen: int, bLen: int): seq[MatchingBlock] =
    ## Find identical blocks in two strings.
    ##
    ## The result is a sequence of `MatchingBlock` objects. It can be used with both editops and
    ## opcodes. The second and third arguments don't have to be actually strings, their lengths are
    ## enough.
    runnableExamples:
        let (a, b) = ("spam", "park")
        let mb = matchingBlocks(editops(a, b), a, b)
        assert mb[0] == MatchingBlock(spos: 1, dpos: 0, `len`: 2)
        ## The last zero-length block is not an error, but it's there for compatibility with Pythons
        ## `difflib` which always emits it.
        assert mb[1] == MatchingBlock(spos: 4, dpos: 4, `len`: 0)
        assert mb == matchingBlocks(editops(a, b), len(a), len(b))
    runnableExamples:
        ## One can join the matching blocks to get two identical strings:
        from sequtils import map
        from strutils import join
        let (a, b) = ("dog kennels", "mattresses")
        let mb = matchingBlocks(editops(a, b), a, b)
        assert join(map(mb, proc (x: MatchingBlock): string =
            a[x.spos ..< x.spos + x.len])) == "ees"
        assert join(map(mb, proc (x: MatchingBlock): string =
            b[x.dpos ..< x.dpos + x.len])) == "ees"
    matchingBlocksCommon(ops, aLen, bLen)

proc matchingBlocks*(ops: seq[EditOp], a: string, b: string): seq[MatchingBlock] =
    matchingBlocksCommon(ops, len(a), len(b))

proc matchingBlocks*(ops: seq[OpCode], aLen: int, bLen: int): seq[MatchingBlock] =
    matchingBlocksCommon(ops, aLen, bLen)

proc matchingBlocks*(ops: seq[OpCode], a: string, b: string): seq[MatchingBlock] =
    matchingBlocksCommon(ops, len(a), len(b))

proc subtractEdit*(ops: seq[EditOp], subsequence: seq[EditOp]): seq[EditOp] =
    ## Subtract an edit subsequence from a sequence.
    ##
    ## The result is equivalent to ``editops(applyEdit(subsequence, s1, s2), s2)``, except that is
    ## constructed directly from the edit operations. That is, if you apply it to the result of
    ## subsequence application, you get the same final string as from application of complete `ops`.
    ## It may be not identical, though (in ambiguous cases, like insertion of a character next to
    ## the same character).
    ##
    ## The subtracted subsequence must be an ordered subset of `ops`.
    ##
    ## Note this function does not accept difflib-style opcodes as no one in his right mind wants to
    ## create subsequences from them.
    runnableExamples:
        let e = editops("man", "scotsman")
        let e1 = e[0..2]
        let bastard = applyEdit(e1, "man", "scotsman")
        assert bastard == "scoman"
        assert applyEdit(subtractEdit(e, e1), bastard, "scotsman") == "scotsman"
    subtract(ops, subsequence)
