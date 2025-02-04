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
JSValue js_create_from_ctor(JSContext *ctx, JSValue ctor, int class_id);
void js_free_prop_enum(JSContext *ctx, JSPropertyEnum *tab, uint32_t len);


// defined in quickjs.c
typedef struct JSRefCountHeader {
    int ref_count;
} JSRefCountHeader;

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

// quickjs.c modifications

/*static void gc_decref_child(JSRuntime *rt, JSGCObjectHeader *p)
{
    if (p->ref_count <= 0) { return; }
    //assert(p->ref_count > 0); -- this is bogus
    p->ref_count--;
    if (p->ref_count == 0 && p->mark == 1) {
        list_del(&p->link);
        list_add_tail(&p->link, &rt->tmp_obj_list);
    }
}*/

/*void JS_FreeContext(JSContext *ctx)
{
    JSRuntime *rt = ctx->rt;
    int i;
    
    if (--ctx->header.ref_count > 0)
        return;
    if (ctx->header.ref_count < 0) { return; } // add this!
    assert(ctx->header.ref_count == 0);
    
    ...
}*/

// comment out in quickjs.c in JS_FreeRuntime
//assert(list_empty(&rt->gc_obj_list));

// in quickjs-libc.c, add this after all the #includes and #defines.
// -- this enables us to work on tvOS.  these functions are only used
// for the file-io capabilities that we don't access.
/*
#include <TargetConditionals.h>
#if TARGET_OS_TV
#define execve(file, argv, envp) ({ assert(!"execve() is not supported on tvOS"); -1; })
#define fork() ({ assert(!"fork() is not supported on tvOS"); -1; })
#endif
 */

#endif // SEGMENT_H
