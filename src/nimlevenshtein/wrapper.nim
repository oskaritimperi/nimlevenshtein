## A thin wrapper around the python-Levenshtein C API.
##
## Using this wrapper you can use Nim strings and sequences instead of passing cstrings and pointers
## to arrays.

import binding

export EditOp
export OpCode
export EditType
export MatchingBlock

converter toLevByte(s: string): ptr lev_byte = cast[ptr lev_byte](s.cstring)

converter toLevByteArray(a: cstringArray): ptr ptr lev_byte = cast[ptr ptr lev_byte](a)

proc cFree(p: pointer) {.importc:"free".}

proc distance*(a, b: string, xcost: int): int =
    ## Computes Levenshtein edit distance of two strings.
    ##
    ## If nonzero, the replace operation has weight 2, otherwise all edit operations have equal
    ## weights of 1.
    lev_edit_distance(len(a), a, len(b), b, xcost.cint)

proc hammingDistance*(a, b: string): int =
    ## Computes Hamming distance of two strings.
    ##
    ## The strings must have the same length.
    assert len(a) == len(b)
    lev_hamming_distance(len(a), a, b)

proc jaroRatio*(a, b: string): float =
    ## Computes Jaro string similarity metric of two strings.
    lev_jaro_ratio(len(a), a, len(b), b)

proc jaroWinklerRatio*(a, b: string, pfweigth: float): float =
    ## Computes Jaro-Winkler string similarity metric of two strings.
    ##
    ## The formula is J+@pfweight*P*(1-J), where J is Jaro metric and P is the length of common
    ## prefix.
    lev_jaro_winkler_ratio(len(a), a, len(b), b, pfweigth)

template medianCommon(f: typed, strings: seq[string], weights: seq[float]) =
    assert len(strings) == len(weights)

    var lengths = newSeqUninitialized[csize](strings.len)
    for i, s in strings:
        lengths[i] = len(s)

    var cstrings = allocCStringArray(strings)
    defer: deallocCStringArray(cstrings)

    var nm: csize

    let r = f(strings.len, lengths[0].addr, cstrings, weights[0].unsafeAddr, nm.addr)
    defer: cFree(r)

    if r == nil and nm > 0:
        raise newException(OutOfMemError, "out of memory")

    result = newString(nm)
    copyMem(result[0].addr, r, nm)

proc greedyMedian*(strings: seq[string], weights: seq[float]): string =
    ## Finds a generalized median string of @strings using the greedy algorithm.
    ##
    ## Note it's considerably more efficient to give a string with weight 2 than to store two
    ## identical strings in `strings` (with weights 1).
    medianCommon(lev_greedy_median, strings, weights)

proc medianImprove*(s: string, strings: seq[string], weights: seq[float]): string =
    ## Tries to make `s` a better generalized median string of `strings` with small perturbations.
    ##
    ## It never returns a string with larger SOD than `s`; in the worst case, a string identical to
    ## `s` is returned.
    assert len(strings) == len(weights)

    var lengths = newSeqUninitialized[csize](strings.len)
    for i, s in strings:
        lengths[i] = len(s)

    var cstrings = allocCStringArray(strings)
    defer: deallocCStringArray(cstrings)

    var nm: csize

    let r = lev_median_improve(len(s), s, strings.len, lengths[0].addr, cstrings, weights[0].unsafeAddr, nm.addr)
    defer: cFree(r)

    if r == nil and nm > 0:
        raise newException(OutOfMemError, "lev_median_improve")

    result = newString(nm)
    copyMem(result[0].addr, r, nm)

proc quickMedian*(strings: seq[string], weights: seq[float]): string =
    medianCommon(lev_quick_median, strings, weights)

proc setMedian*(strings: seq[string], weights: seq[float]): string =
    ## Finds the median string of a string set `strings`.
    medianCommon(lev_set_median, strings, weights)

template setSeqCommon(f: typed, a: seq[string], b: seq[string]): float =
    var ca = allocCStringArray(a)
    defer: deallocCStringArray(ca)

    var la = newSeqUninitialized[csize](len(a))
    for i, s in a:
        la[i] = len(s)

    var cb = allocCStringArray(b)
    defer: deallocCStringArray(cb)

    var lb = newSeqUninitialized[csize](len(b))
    for i, s in b:
        lb[i] = len(s)

    f(len(a), la[0].addr, ca, len(b), lb[0].addr, cb)

proc editSeqDistance*(a: seq[string], b: seq[string]): float =
    ## Finds the distance between string sequences `a` and `b`.
    ##
    ## In other words, this is a double-Levenshtein algorithm.
    ##
    ## The cost of string replace operation is based on string similarity: it's zero for identical
    ## strings and 2 for completely unsimilar strings.
    setSeqCommon(lev_edit_seq_distance, a, b)

proc setDistance*(a: seq[string], b: seq[string]): float =
    ## Finds the distance between string sets `a` and `b`.
    ##
    ## The difference from `editSeqDistance()` is that order doesn't matter. The optimal association
    ## of `a` and `b` is found first and the similarity is computed for that.
    ##
    ## Uses sequential Munkers-Blackman algorithm.
    setSeqCommon(lev_set_distance, a, b)

proc checkErrors*(len1: int, len2: int, ops: seq[EditOp]) =
    ## Checks whether `ops` is consistent and applicable as a partial edit from a string of length
    ## `len1` to a string of length `len2`.
    ##
    ## Raises an exception if there are errors.
    if lev_editops_check_errors(len1, len2, len(ops), ops[0].unsafeAddr) != 0:
        raise newException(Exception, "edit operations are invalid or inapplicable")

proc checkErrors*(len1: int, len2: int, bops: seq[OpCode]) =
    ## Checks whether `bops` is consistent and applicable as an edit from a string of length `len1`
    ## to a string of length `len2`.
    ##
    ## Raises an exception if there are errors.
    if lev_opcodes_check_errors(len1, len2, len(bops), bops[0].unsafeAddr) != 0:
        raise newException(Exception, "edit operations are invalid or inapplicable")

proc invert*(ops: var seq[EditOp]) =
    ## Inverts the sense of `ops`. It is modified in place.
    ##
    ## In other words, `ops` becomes a valid partial edit for the original source and destination
    ## strings with their roles exchanged.
    lev_editops_invert(len(ops), ops[0].addr)

proc invert*(ops: var seq[OpCode]) =
    ## Inverts the sense of `ops`.  It is modified in place.
    ##
    ## In other words, `ops` becomes a partial edit for the original source and destination strings
    ## with their roles exchanged.
    lev_opcodes_invert(len(ops), ops[0].addr)

proc matchingBlocks*(len1: int, len2: int, ops: seq[EditOp]): seq[MatchingBlock] =
    ## Computes the matching block corresponding to an optimal edit `ops`.
    var nmblocks: csize
    let mblocks = lev_editops_matching_blocks(len1, len2, len(ops), ops[0].unsafeAddr, nmblocks.addr)
    defer: cFree(mblocks)
    if mblocks == nil and nmblocks > 0:
        raise newException(OutOfMemError, "lev_editops_matching_blocks")
    result = newSeq[MatchingBlock](nmblocks)
    copyMem(result[0].addr, mblocks, sizeof(MatchingBlock)*nmblocks)

proc matchingBlocks*(len1: int, len2: int, ops: seq[OpCode]): seq[MatchingBlock] =
    ## Computes the matching block corresponding to an optimal edit `ops`.
    var nmblocks: csize
    let mblocks = lev_opcodes_matching_blocks(len1, len2, len(ops), ops[0].unsafeAddr, nmblocks.addr)
    defer: cFree(mblocks)
    if mblocks == nil and nmblocks > 0:
        raise newException(OutOfMemError, "lev_opcodes_matching_blocks")
    result = newSeq[MatchingBlock](nmblocks)
    copyMem(result[0].addr, mblocks, sizeof(MatchingBlock)*nmblocks)

proc apply*(string1: string, string2: string, ops: seq[EditOp]): string =
    ## Applies a partial edit `ops` from `string1` to `string2`.
    ##
    ## NB: `ops` is not checked for applicability.
    var nr: csize
    let r = lev_editops_apply(len(string1), string1, len(string2), string2, len(ops), ops[0].unsafeAddr, nr.addr)
    defer: cFree(r)
    if r == nil and nr > 0:
        raise newException(OutOfMemError, "lev_editops_apply")
    result = newString(nr)
    copyMem(result[0].addr, r, nr)

proc apply*(string1: string, string2: string, ops: seq[OpCode]): string =
    ## Applies a sequence of difflib block operations to a string.
    ##
    ## NB: `ops` is not checked for applicability.
    var nr: csize
    let r = lev_opcodes_apply(len(string1), string1, len(string2), string2, len(ops), ops[0].unsafeAddr, nr.addr)
    defer: cFree(r)
    if r == nil and nr > 0:
        raise newException(OutOfMemError, "lev_opcodes_apply")
    result = newString(nr)
    copyMem(result[0].addr, r, nr)

proc editops*(string1: string, string2: string): seq[EditOp] =
    ## Find an optimal edit sequence from `string1` to `string2`.
    ##
    ## When there's more than one optimal sequence, a one is arbitrarily (though deterministically)
    ## chosen.
    ##
    ## The return value is normalized, i.e., keep operations are not included.
    var n: csize
    let ops = lev_editops_find(len(string1), string1, len(string2), string2, n.addr)
    defer: cFree(ops)
    if ops == nil and n > 0:
        raise newException(OutOfMemError, "lev_editops_find")
    result = newSeq[EditOp](n)
    copyMem(result[0].addr, ops, sizeof(EditOp)*n)

proc toEditOps*(ops: seq[OpCode], keepkeep: bool): seq[EditOp] =
    ## Converts difflib block operation codes to elementary edit operations.
    ##
    ## If `keepkeep` is true, keep operations will be included. Otherwise the result will be
    ## normalized, i.e. without any keep operations.
    var n: csize
    let r = lev_opcodes_to_editops(len(ops), ops[0].unsafeAddr, n.addr, keepkeep.cint)
    defer: cFree(r)
    if r == nil and n > 0:
        raise newException(OutOfMemError, "lev_opcodes_to_editops")
    result = newSeq[EditOp](n)
    copyMem(result[0].addr, r, sizeof(EditOp)*n)

proc toOpCodes*(ops: seq[EditOp], len1: int, len2: int): seq[OpCode] =
    ## Converts elementary edit operations to difflib block operation codes.
    ##
    ## Note the string lengths are necessary since difflib doesn't allow omitting keep operations.
    var n: csize
    let r = lev_editops_to_opcodes(len(ops), ops[0].unsafeAddr, n.addr, len1, len2)
    defer: cFree(r)
    if r == nil and n > 0:
        raise newException(OutOfMemError, "lev_editops_to_opcodes")
    result = newSeq[OpCode](n)
    copyMem(result[0].addr, r, sizeof(OpCode)*n)

proc totalCost*(ops: seq[EditOp]): int =
    ## Computes the total cost of operations in `ops`.
    ##
    ## The costs of elementary operations are all 1.
    lev_editops_total_cost(len(ops), ops[0].unsafeAddr)

proc totalCost*(ops: seq[OpCode]): int =
    ## Computes the total cost of operations in `ops`.
    ##
    ## The costs of elementary operations are all 1.
    lev_opcodes_total_cost(len(ops), ops[0].unsafeAddr)

proc normalize*(ops: seq[EditOp]): seq[EditOp] =
    ## Normalizes a list of edit operations to contain no keep operations.
    var n: csize
    let r = lev_editops_normalize(len(ops), ops[0].unsafeAddr, n.addr)
    defer: cFree(r)
    if r == nil and n > 0:
        raise newException(OutOfMemError, "lev_editops_normalize")
    result = newSeq[EditOp](n)
    copyMem(result[0].addr, r, sizeof(EditOp)*n)

proc subtract*(ops: seq[EditOp], sub: seq[EditOp]): seq[EditOp] =
    ## Subtracts a subsequence of elementary edit operations from a sequence.
    ##
    ## The remainder is a sequence that, applied to result of application of `sub`, gives the same
    ## final result as application of `ops` to original string.
    var n: csize
    let r = lev_editops_subtract(len(ops), ops[0].unsafeAddr, len(sub), sub[0].unsafeAddr, n.addr)
    defer: cFree(r)
    if r == nil and n == cast[csize](-1):
        raise newException(Exception, "lev_editops_subtract failed")
    result = newSeq[EditOp](n)
    copyMem(result[0].addr, r, sizeof(EditOp)*n)
