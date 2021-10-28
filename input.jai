#import "Windows";
//TODO: other OS support

kernel32 :: #foreign_system_library "kernel32";

stdin  : HANDLE;
stdout : HANDLE;

ReadConsoleA :: (
    hConsoleInput: HANDLE,
    lpBuffer: *u8,
    nNumberOfCharsToRead: s32,
    lpNumberOfCharsRead: *s32,
    pInputControl: *void = null
) -> BOOL #foreign kernel32;

init_input :: () {
    stdin = GetStdHandle(STD_INPUT_HANDLE);
}

get_input :: () -> string {
    MAX_BYTES_TO_READ :: 1024;
    temp : [MAX_BYTES_TO_READ] u8;
    result: string = ---;
    bytes_read : s32;
    
    if !ReadConsoleA(stdin, temp.data, xx temp.count, *bytes_read)
        return "";

    result.data = alloc(bytes_read);
    result.count = bytes_read;
    memcpy(result.data, temp.data, bytes_read);
    return result;
}
