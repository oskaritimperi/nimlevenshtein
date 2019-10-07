## Low-level bindings to python-Levenshtein C API.

{.passC:"-DNO_PYTHON -Dlev_wchar=int".}
{.compile:"_levenshtein.c".}

when defined(linux):
  {.passL:"-lm".}

type
  lev_byte* = cuchar

  EditType* {.pure.} = enum
    ## Edit operation type
    Keep = 0     ##  Keep, sometimes called *equal*
    Replace = 1  ##  Substitution
    Insert = 2   ##  Insertion
    Delete = 3   ##  Deletion
    Last         ##  sometimes returned when an error occurs

  EditOpError* {.pure.} = enum
    ##  Error codes returned by editop check functions
    Ok = 0,      ##  no error
    Type,        ##  nonexistent edit type
    Out,         ##  edit out of string bounds
    Order,       ##  ops are not ordered
    Block,       ##  incosistent block boundaries (block ops)
    Span,        ##  sequence is not a full transformation (block ops)
    Last

  EditOp* {.bycopy.} = object
    ##  Edit operation (atomic).
    ##
    ##  This is the `native` atomic edit operation.  It differs from the difflib one's because it
    ##  represents a change of one character, not a block.  And we usually don't care about
    ##  `EditType.Keep`, though the functions can handle them.  The positions are interpreted as at
    ##  the left edge of a character.
    `type`*: EditType          ##  editing operation type
    spos*: csize               ##  source block position
    dpos*: csize               ##  destination position

  OpCode* {.bycopy.} = object
    ##  Edit operation (difflib-compatible).
    ##
    ##  This is not `native`, but conversion functions exist. These fields exactly correspond to
    ##  the codeops() tuples fields (and this method is also the source of the silly OpCode name).
    ##  Sequences must span over complete strings, subsequences are simply edit sequences with more
    ##  (or larger) `EditType.Keep` blocks.
    `type`*: EditType          ##  editing operation type
    sbeg*: csize               ##  source block begin
    send*: csize               ##  source block end
    dbeg*: csize               ##  destination block begin
    dend*: csize               ##  destination block end

  MatchingBlock* {.bycopy.} = object
    ##  Matching block (difflib-compatible).
    spos*: csize  ##  source block position
    dpos*: csize  ##  destination block position
    len*: csize   ##  block length

proc lev_edit_distance*(len1: csize; string1: ptr lev_byte; len2: csize;
                       string2: ptr lev_byte; xcost: cint): csize {.importc.}
proc lev_u_edit_distance*(len1: csize; string1: ptr int32; len2: csize;
                         string2: ptr int32; xcost: cint): csize {.importc.}
proc lev_hamming_distance*(len: csize; string1: ptr lev_byte; string2: ptr lev_byte): csize {.
    importc.}
proc lev_u_hamming_distance*(len: csize; string1: ptr int32; string2: ptr int32): csize {.
    importc.}
proc lev_jaro_ratio*(len1: csize; string1: ptr lev_byte; len2: csize;
                    string2: ptr lev_byte): cdouble {.importc.}
proc lev_u_jaro_ratio*(len1: csize; string1: ptr int32; len2: csize; string2: ptr int32): cdouble {.
    importc.}
proc lev_jaro_winkler_ratio*(len1: csize; string1: ptr lev_byte; len2: csize;
                            string2: ptr lev_byte; pfweight: cdouble): cdouble {.importc.}
proc lev_u_jaro_winkler_ratio*(len1: csize; string1: ptr int32; len2: csize;
                              string2: ptr int32; pfweight: cdouble): cdouble {.importc.}
proc lev_greedy_median*(n: csize; lengths: ptr csize; strings: ptr ptr lev_byte;
                       weights: ptr cdouble; medlength: ptr csize): ptr lev_byte {.importc.}
proc lev_u_greedy_median*(n: csize; lengths: ptr csize; strings: ptr ptr int32;
                         weights: ptr cdouble; medlength: ptr csize): ptr int32 {.importc.}
proc lev_median_improve*(len: csize; s: ptr lev_byte; n: csize; lengths: ptr csize;
                        strings: ptr ptr lev_byte; weights: ptr cdouble;
                        medlength: ptr csize): ptr lev_byte {.importc.}
proc lev_u_median_improve*(len: csize; s: ptr int32; n: csize; lengths: ptr csize;
                          strings: ptr ptr int32; weights: ptr cdouble;
                          medlength: ptr csize): ptr int32 {.importc.}
proc lev_quick_median*(n: csize; lengths: ptr csize; strings: ptr ptr lev_byte;
                      weights: ptr cdouble; medlength: ptr csize): ptr lev_byte {.importc.}
proc lev_u_quick_median*(n: csize; lengths: ptr csize; strings: ptr ptr int32;
                        weights: ptr cdouble; medlength: ptr csize): ptr int32 {.importc.}
proc lev_set_median*(n: csize; lengths: ptr csize; strings: ptr ptr lev_byte;
                    weights: ptr cdouble; medlength: ptr csize): ptr lev_byte {.importc.}
proc lev_set_median_index*(n: csize; lengths: ptr csize; strings: ptr ptr lev_byte;
                          weights: ptr cdouble): csize {.importc.}
proc lev_u_set_median*(n: csize; lengths: ptr csize; strings: ptr ptr int32;
                      weights: ptr cdouble; medlength: ptr csize): ptr int32 {.importc.}
proc lev_u_set_median_index*(n: csize; lengths: ptr csize; strings: ptr ptr int32;
                            weights: ptr cdouble): csize {.importc.}
proc lev_edit_seq_distance*(n1: csize; lengths1: ptr csize;
                           strings1: ptr ptr lev_byte; n2: csize; lengths2: ptr csize;
                           strings2: ptr ptr lev_byte): cdouble {.importc.}
proc lev_u_edit_seq_distance*(n1: csize; lengths1: ptr csize; strings1: ptr ptr int32;
                             n2: csize; lengths2: ptr csize; strings2: ptr ptr int32): cdouble {.
    importc.}
proc lev_set_distance*(n1: csize; lengths1: ptr csize; strings1: ptr ptr lev_byte;
                      n2: csize; lengths2: ptr csize; strings2: ptr ptr lev_byte): cdouble {.
    importc.}
proc lev_u_set_distance*(n1: csize; lengths1: ptr csize; strings1: ptr ptr int32;
                        n2: csize; lengths2: ptr csize; strings2: ptr ptr int32): cdouble {.
    importc.}
proc lev_editops_check_errors*(len1: csize; len2: csize; n: csize; ops: ptr EditOp): cint {.
    importc.}
proc lev_opcodes_check_errors*(len1: csize; len2: csize; nb: csize; bops: ptr OpCode): cint {.
    importc.}
proc lev_editops_invert*(n: csize; ops: ptr EditOp) {.importc.}
proc lev_opcodes_invert*(nb: csize; bops: ptr OpCode) {.importc.}
proc lev_editops_matching_blocks*(len1: csize; len2: csize; n: csize;
                                 ops: ptr EditOp; nmblocks: ptr csize): ptr MatchingBlock {.
    importc.}
proc lev_opcodes_matching_blocks*(len1: csize; len2: csize; nb: csize;
                                 bops: ptr OpCode; nmblocks: ptr csize): ptr MatchingBlock {.
    importc.}
proc lev_editops_apply*(len1: csize; string1: ptr lev_byte; len2: csize;
                       string2: ptr lev_byte; n: csize; ops: ptr EditOp;
                       len: ptr csize): ptr lev_byte {.importc.}
proc lev_u_editops_apply*(len1: csize; string1: ptr int32; len2: csize;
                         string2: ptr int32; n: csize; ops: ptr EditOp;
                         len: ptr csize): ptr int32 {.importc.}
proc lev_opcodes_apply*(len1: csize; string1: ptr lev_byte; len2: csize;
                       string2: ptr lev_byte; nb: csize; bops: ptr OpCode;
                       len: ptr csize): ptr lev_byte {.importc.}
proc lev_u_opcodes_apply*(len1: csize; string1: ptr int32; len2: csize;
                         string2: ptr int32; nb: csize; bops: ptr OpCode;
                         len: ptr csize): ptr int32 {.importc.}
proc lev_editops_find*(len1: csize; string1: ptr lev_byte; len2: csize;
                      string2: ptr lev_byte; n: ptr csize): ptr EditOp {.importc.}
proc lev_u_editops_find*(len1: csize; string1: ptr int32; len2: csize;
                        string2: ptr int32; n: ptr csize): ptr EditOp {.importc.}
proc lev_opcodes_to_editops*(nb: csize; bops: ptr OpCode; n: ptr csize; keepkeep: cint): ptr EditOp {.
    importc.}
proc lev_editops_to_opcodes*(n: csize; ops: ptr EditOp; nb: ptr csize; len1: csize;
                            len2: csize): ptr OpCode {.importc.}
proc lev_editops_total_cost*(n: csize; ops: ptr EditOp): csize {.importc.}
proc lev_opcodes_total_cost*(nb: csize; bops: ptr OpCode): csize {.importc.}
proc lev_editops_normalize*(n: csize; ops: ptr EditOp; nnorm: ptr csize): ptr EditOp {.
    importc.}
proc lev_editops_subtract*(n: csize; ops: ptr EditOp; ns: csize; sub: ptr EditOp;
                          nrem: ptr csize): ptr EditOp {.importc.}


proc lev_init_rng*(seed: culong) {.importc.}
