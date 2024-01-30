#ifndef SEGMENT_H
#define SEGMENT_H

//extern char **environ;
//#define sighandler_t __sighandler_t
//#define CONFIG_VERSION "segment-1.0.0"

#include "quickjs.h"
#include "quickjs-libc.h"
#include "quickjs-atom.h"
#include "quickjs-opcode.h"
#include "quickjs-c-atomics.h"
#include "cutils.h"
#include "libbf.h"
#include "libunicode.h"
#include "libunicode-table.h"
#include "libregexp.h"
#include "libregexp-opcode.h"
#include "list.h"
#include "unicode_gen_def.h"


// this needs `static` removed from the original definition
// to make it accessible outside.
JSValue js_create_from_ctor(JSContext *ctx, JSValueConst ctor, int class_id);
void js_free_prop_enum(JSContext *ctx, JSPropertyEnum *tab, uint32_t len);

static int32_t js_get_refcount(JSValue v) {
    JSRefCountHeader *p = (JSRefCountHeader *)JS_VALUE_GET_PTR(v);
    return p->ref_count;
}

static void js_decrement_refcount(JSValue v) {
    JSRefCountHeader *p = (JSRefCountHeader *)JS_VALUE_GET_PTR(v);
    if (p->ref_count > 0) {
        p->ref_count--;
    }
}

#endif // SEGMENT_H
