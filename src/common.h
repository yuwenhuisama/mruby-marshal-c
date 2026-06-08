#define MARSHAL_MAJOR 4
#define MARSHAL_MINOR 8

#define TYPE_NIL '0'
#define TYPE_TRUE 'T'
#define TYPE_FALSE 'F'
#define TYPE_FIXNUM 'i'

#define TYPE_EXTENDED 'e'
#define TYPE_UCLASS 'C'
#define TYPE_OBJECT 'o'
#define TYPE_DATA 'd'
#define TYPE_USERDEF 'u'
#define TYPE_USRMARSHAL 'U'
#define TYPE_FLOAT 'f'
#define TYPE_BIGNUM 'l'
#define TYPE_STRING '"'
#define TYPE_REGEXP '/'
#define TYPE_ARRAY '['
#define TYPE_HASH '{'
#define TYPE_HASH_DEF '}'
#define TYPE_STRUCT 'S'
#define TYPE_MODULE_OLD 'M'
#define TYPE_CLASS 'c'
#define TYPE_MODULE 'm'

#define TYPE_SYMBOL ':'
#define TYPE_SYMLINK ';'

#define TYPE_IVAR 'I'
#define TYPE_LINK '@'

// mruby 4.0.0 removed MRB_NO_PRESYM, so the compile-time MRB_SYM(x) macro can no
// longer be used by this out-of-tree gem (its symbols are not in the host's
// generated presym id.h). Intern the symbols at runtime instead; every use site
// below has `mrb` in scope, and mrb_intern_lit yields the identical mrb_sym.
#define s_dump mrb_intern_lit(mrb, "_dump")
#define s_load mrb_intern_lit(mrb, "_load")
#define s_mdump mrb_intern_lit(mrb, "marshal_dump")
#define s_mload mrb_intern_lit(mrb, "marshal_load")
#define s_dump_data mrb_intern_lit(mrb, "_dump_data")
#define s_load_data mrb_intern_lit(mrb, "_load_data")
#define s_alloc mrb_intern_lit(mrb, "_alloc")
#define s_call mrb_intern_lit(mrb, "call")
#define s_getbyte mrb_intern_lit(mrb, "getbyte")
#define s_read mrb_intern_lit(mrb, "read")
#define s_write mrb_intern_lit(mrb, "write")
#define s_binmode mrb_intern_lit(mrb, "binmode")

#define RSHIFT(x, y) ((x) >> (int)y)
#define FLOAT_DIG 17
#define DECIMAL_MANT (53 - 16) /* from IEEE754 double precision */
#define SIZEOF_LONG 4
