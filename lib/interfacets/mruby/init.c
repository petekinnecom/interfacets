#include <mruby.h>
#include <mruby/irep.h>
#include <emscripten.h>

mrb_value js_eval(mrb_state* mrb, mrb_value self)
{
  char *js_code;
  mrb_get_args(mrb, "z", &js_code);
  emscripten_run_script(js_code);
  return self;
}

mrb_state *mrb;
void EMSCRIPTEN_KEEPALIVE ruby_eval(char* str, char* path) {
  mrb_funcall(
    mrb,
    mrb_top_self(mrb),
    "wrapped_eval",
    2,
    mrb_str_new_cstr(mrb, str),
    mrb_str_new_cstr(mrb, path)
  );

  if (mrb->exc) mrb_print_error(mrb);
}

// json of the form:
// {receiver: , method:, args: [ ...] ]
void EMSCRIPTEN_KEEPALIVE ruby_call(char* json) {
  mrb_funcall(
    mrb,
    mrb_top_self(mrb),
    "wrapped_call",
    1,
    mrb_str_new_cstr(mrb, json)
  );

  if (mrb->exc) mrb_print_error(mrb);
}

int main() {
  // Leave this open for all eternity
  mrb = mrb_open();

  if (!mrb) { /* handle error */ }

  mrb_define_method(
    mrb,
    mrb->kernel_module,
    "js_eval",
    js_eval,
    MRB_ARGS_REQ(1)
  );

  mrb_load_irep(mrb, ruby_app);

  // If an exception, print error
  if (mrb->exc) mrb_print_error(mrb);

  return 0;
}
