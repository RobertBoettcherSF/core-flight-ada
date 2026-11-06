void __gnat_last_chance_handler (char *file, int line) {
  (void)file; (void)line; __builtin_trap();
}
void system__assertions__raise_assert_failure (void *msg, void *file, int line) {
  (void)msg; (void)file; (void)line; __builtin_trap();
}
