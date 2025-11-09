#include "my_application.h"
#include <locale.h>
#include <cstdlib>

int main(int argc, char** argv) {
  setenv("LC_ALL", "C", 1);
  setenv("LC_NUMERIC", "C", 1);
  setenv("LANG", "C", 1);
  setlocale(LC_ALL, "C");
  setlocale(LC_NUMERIC, "C");
  
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
