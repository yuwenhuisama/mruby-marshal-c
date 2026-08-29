# roundtrip.rb -- Marshal.load(Marshal.dump(x)) == x  round-trip harness (TDD RED)
#
# PURPOSE (T8): Build SYNTHETIC in-VM objects (NO external .rvdata2 files) and assert
# that every value survives a Marshal dump/load round-trip. On the UNPATCHED gem this
# file is RED on purpose: it documents two known bugs that T17 (the C fix) must close.
#
#   BUG 1  w_objivar (src/dump.c ~L332-336 / used at L587) writes the TYPE_OBJECT ivar
#          PAIRS but never the leading ivar COUNT, while the load side r_ivar
#          (src/load.c ~L292) reads a count first. => any object with >=1 ivar is
#          corrupt and load raises / mis-reads. (Hash/Array/Struct DO write counts and
#          therefore round-trip fine -- only TYPE_OBJECT 'o' is broken.)
#   BUG 2  has_ivars(...) is hard-coded FALSE (src/dump.c ~L345) so the String :E
#          encoding wrapper (TYPE_IVAR) is never emitted. => CJK / non-ASCII strings
#          lose their encoding flag on the wire.
#
# RUN RECIPE (as mandated by the task):
#   cd E:\Projects\RGSS-Godot\mruby-ext && xmake && mruby marshal/mruby-marshal-c/test/roundtrip.rb
#
# NOTE ON RUNNING: the marshal gem ships as a P/Invoke DLL; the prebuilt host
# `mruby.exe` in this checkout is NOT linked with Marshal (`uninitialized constant
# Marshal`). To exercise it you need an mruby that has called
# `mrb_mruby_marshal_c_gem_init` (the C# host, a Marshal-enabled mruby build, or the
# tiny link-the-gem runner used to capture .sisyphus/evidence/task-8-red.txt).
#
# EXPECTATION ON UNPATCHED GEM:
#   Group 1 (basic types) ...... MUST PASS  -> proves the harness itself is valid
#   Group 2 (CJK string) ....... RED expected (encoding wrapper missing; mruby String#==
#                                compares BYTES, so it may still report equal -- the
#                                diagnostics below capture what actually happens)
#   Group 3 (object, 2 ivars) .. RED expected (ivar-count bug)
#   Group 4 (object, CJK ivar) . RED expected (ivar-count + encoding bugs)
#
# CURRENT STATE: both bugs are fixed on this branch (see the commit that writes the
# objivar count and emits the String :E wrapper), so this file is expected to be
# GREEN here. The RED description above is kept deliberately -- it documents what the
# harness was built to catch, and reverting either fix should turn Groups 3/4 red
# again. Treat that as the regression signal.

# --- minimal self-contained assert (bare mruby has no mrbtest `assert do..end` DSL) ---
$pass = 0
$fail = 0

def assert(condition, message)
  if condition
    $pass += 1
    puts "  [PASS] #{message}"
  else
    $fail += 1
    puts "  [FAIL] #{message}"
  end
  condition
end

# Exception-safe round-trip. Returns [equal?, detail]. Separates the DUMP stage from
# the LOAD stage so a corrupt-stream failure is attributed correctly in the output.
def rt(x)
  begin
    dumped = Marshal.dump(x)
  rescue => e
    return [false, "DUMP raised #{e.class}: #{e.message}"]
  end
  begin
    loaded = Marshal.load(dumped)
  rescue => e
    return [false, "LOAD raised #{e.class}: #{e.message}"]
  end
  [loaded == x, loaded]
end

# --- synthetic test classes (defined inline; deep-compared via custom ==) ---
class TestObj
  attr_reader :a, :b
  def initialize(a, b)
    @a = a
    @b = b
  end
  def ==(other)
    other.is_a?(TestObj) && @a == other.a && @b == other.b
  end
end

class TestCJK
  attr_reader :name
  def initialize(name)
    @name = name
  end
  def ==(other)
    other.is_a?(TestCJK) && @name == other.name
  end
end

# Marshal-presence probe WITHOUT the `defined?` keyword (this mruby build parses
# `defined?` as an ordinary method call and raises NoMethodError). Referencing an
# undefined constant raises NameError, which rescue turns into a clean false.
marshal_present = ((Marshal rescue nil) ? true : false)

puts "=== T8 roundtrip.rb : Marshal round-trip RED harness ==="
puts "Marshal present? #{marshal_present ? 'yes' : 'NO'}"
puts ""

# ---------------------------------------------------------------------------
puts "--- Group 1: basic types (MUST PASS -- proves harness validity) ---"
ok, got = rt(:foo);        assert(ok, "Symbol  :foo         -> #{got.inspect}")
ok, got = rt(:another);    assert(ok, "Symbol  :another     -> #{got.inspect}")
ok, got = rt(0);           assert(ok, "Integer 0            -> #{got.inspect}")
ok, got = rt(42);          assert(ok, "Integer 42           -> #{got.inspect}")
ok, got = rt(123);         assert(ok, "Integer 123          -> #{got.inspect}")
ok, got = rt(-1234);       assert(ok, "Integer -1234        -> #{got.inspect}")
ok, got = rt(nil);         assert(ok, "nil                  -> #{got.inspect}")
ok, got = rt(true);        assert(ok, "true                 -> #{got.inspect}")
ok, got = rt(false);       assert(ok, "false                -> #{got.inspect}")
ok, got = rt("hello");     assert(ok, "String  \"hello\"      -> #{got.inspect}")
ok, got = rt([1, 2, 3]);   assert(ok, "Array   [1,2,3]      -> #{got.inspect}")
ok, got = rt([:a, 1, nil]);assert(ok, "Array   [:a,1,nil]   -> #{got.inspect}")
ok, got = rt({});          assert(ok, "Hash    {}           -> #{got.inspect}")
ok, got = rt({a: 1, b: 2});assert(ok, "Hash    {a:1,b:2}    -> #{got.inspect}")

# ---------------------------------------------------------------------------
puts ""
puts "--- Group 2: CJK string (EXPECTED RED -- missing :E encoding wrapper) ---"
s = "\u5730\u56fe\u540d" # "地图名"
raw = Marshal.dump(s)
# Wire-level proof of BUG 2: a correctly-encoded UTF-8 String marshal stream is
#   \x04\x08 I "  <len> <utf8 bytes> \x06 : \x06 E T
# i.e. byte index 2 is 'I' (0x49 TYPE_IVAR) and a ":\x06E" + T encoding pair
# trails the data. The unpatched gem emits a bare \x04\x08"<len>... with NO 'I'
# wrapper and NO :E pair, so the loaded string silently loses its encoding flag.
wrapper_byte = raw.bytes[2]
has_ivar_wrapper = (wrapper_byte == 0x49) # 'I' == TYPE_IVAR
has_E_pair = raw.bytes.include?(0x45)     # 'E' encoding-name symbol present?
puts "  diag: dump bytes = #{raw.bytes.inspect}"
puts "  diag: byte[2]=#{wrapper_byte} (0x49 'I' = TYPE_IVAR wrapper expected); present=#{has_ivar_wrapper}"
puts "  diag: ':E' encoding pair present=#{has_E_pair}"
ok, got = rt(s)
loaded_bytes = got.respond_to?(:bytesize) ? got.bytesize : "n/a"
puts "  diag: original bytesize=#{s.bytesize}, loaded bytesize=#{loaded_bytes}"
puts "  diag: NOTE -- mruby String#== compares BYTES, so a UTF-8-only build may"
puts "        report equal even though the :E encoding wrapper was dropped on the"
puts "        wire (visible above). Cross-VM/CRuby .rvdata2 interop is what breaks."
# Two assertions: (1) the honest in-VM byte round-trip, (2) the wire-level RED that
# documents the missing encoding wrapper (this one FAILS on the unpatched gem).
assert(ok, "CJK String byte round-trip (in-VM, == is byte compare) -> equal?=#{ok}")
assert(has_ivar_wrapper && has_E_pair,
       "CJK String emits :E encoding wrapper on the wire (BUG 2 -> expected FAIL pre-T17)")

# ---------------------------------------------------------------------------
puts ""
puts "--- Group 3: Object with 2 ivars (EXPECTED RED -- w_objivar count bug) ---"
obj = TestObj.new(1, 2)
ok, got = rt(obj)
assert(ok, "TestObj(@a=1,@b=2) round-trip -> #{got.inspect}")

# ---------------------------------------------------------------------------
puts ""
puts "--- Group 4: Object with CJK ivar (EXPECTED RED -- count + encoding bugs) ---"
cobj = TestCJK.new("\u5730\u56fe\u540d")
ok, got = rt(cobj)
assert(ok, "TestCJK(@name=\"\u5730\u56fe\u540d\") round-trip -> #{got.inspect}")

# ---------------------------------------------------------------------------
puts ""
puts "=== SUMMARY ==="
puts "PASS=#{$pass}  FAIL=#{$fail}"
puts ""
puts "Harness validity gate: Group 1 (basic types) must be all-PASS."
puts "TDD RED gate: Group 3 & 4 (object ivars) must FAIL on the unpatched gem;"
puts "T17's C fix flips them GREEN and this whole file should then exit 0."
if $fail > 0
  puts "RESULT: RED  (failures present -- intended pre-T17 state)"
else
  puts "RESULT: GREEN (all round-trips survived)"
end
