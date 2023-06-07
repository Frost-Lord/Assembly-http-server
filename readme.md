# HTTP Assembly Server

##Run:

Ubuntu
```
nasm -f elf64 server.asm && ld -o server server.o && ./server
```

```
make build && ./server
```
OR
```
./Run-NASM.sh server.asm
```

Listening on http://127.0.0.1:3926


## General Info

String.asm
```
. string_itoa: Converts an integer value to a string representation.
. string_atoi: Converts a string representation of an integer to an actual integer value.
. string_copy: Copies a string from one location to another.
. string_concat_int: Concatenates a string with the string representation of an integer.
. string_concat: Concatenates two strings together.
. string_contains: Checks if a string contains another string.
. string_remove: Removes occurrences of a specific string from another string.
. string_ends_with: Checks if a string ends with another string.
. string_char_at_reverse: Checks if a character at a specific position in a string matches a given character, starting from the end of the string.
. print_line: Prints a line of text.
. get_string_length: Retrieves the length of a string.
. get_number_of_digits: Calculates the number of digits in an integer value.
```