build :: () {
    w := compiler_create_workspace("Target Program");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }
    cwd := get_working_directory();
    target_options := get_build_options(w);
    target_options.output_type = .EXECUTABLE;
    target_options.output_path = tprint("%/bin/", cwd);
    target_options.intermediate_path = tprint("%/.build", cwd);
    target_options.output_executable_name = get_current_project_name();
    set_build_options(target_options, w);
    compiler_begin_intercept(w);

    file := tprint("%/%.jai", cwd, "main");
    print("adding %\n", file);

    add_build_file(file, w);

    message_loop();

    compiler_end_intercept(w);
    sleep_milliseconds(500); // temporary? stop output from overwriting prompt
}

execute :: (cmd: string, args: [] string) {
    if cmd == {
        case "help";
            if args.count == {
                case 0;
                    print(HELP);
                case 1;
                    if args[0] == {
                        case "help";
                            print(HELP_HELP);
                        case "new";
                            print(HELP_NEW);
                        case "prompt";
                            print(HELP_PROMPT);
                        case "build";
                            print(HELP_BUILD);
                        case;
                            print("Help: no help information for `%`.\n", cmd);
                    }
                    return;
                case;
                    print_error_incorrect_argument_count(.[0, 1]);
            }
            return;
        
        case "new";
            if args.count == {
                case 1;
                    project_name := args[0];
                    print("Making new project \"%\"...\n", project_name);
                    if !make_directory_if_it_does_not_exist(project_name) {
                        print("Error: failed to create \"%\" directory for project.\n", project_name);
                        return;
                    }
                    cwd := tprint("%/%", get_working_directory(), project_name);
                    if !set_working_directory(cwd) {
                        print("Error: failed to set the current working directory to \"%\".\n", cwd);
                        return;
                    }
                    for string.["bin", "entities", "modules", "modules/jrc"] {
                        if !make_directory_if_it_does_not_exist(it) {
                            print(ERROR_DIRECTORY_CREATION_FAILED, it);
                            return;
                        }
                    }
                    if !write_entire_file("main.jai", SAMPLE_MAIN_FILE) {
                        print("Error: failed to create \"main.jai\".\n");
                        return;
                    }

                    target_directory := tprint("%/modules/jrc", get_working_directory());
                    visitor :: (info: *File_Visit_Info, target_directory: string) {
                        src := info.full_name;
                        dest := tprint("%/%", target_directory, info.short_name);
                        if !copy_file(src, dest) {
                            print("Error: failed to copy % to %.\n", src, dest);
                        }
                    }
                    visit_files(
                        dir_name=tprint("%module", #filepath),
                        recursive=false,
                        user_data=target_directory,
                        proc=visitor,
                        visit_files=true,
                        visit_directories=true
                    );
                case;
                    print_error_incorrect_argument_count(.[1]);
            }
        
        case "prompt";
            if interactive_mode {
                print("Error: cannot run interactive prompt from within interactive prompt.\n");
                return;
            }
            if args.count == {
                case 0;
                    print("Starting jrc interactive prompt, type `exit` or ^C to end.\n");
                    init_input();
                    interactive_mode = true;
                    while interactive_mode {
                        reset_temporary_storage();
                        print_command_prompt();
                        raw_input := get_input();
                        if raw_input.count == 0 break;
                        input: string;
                        found: bool;
                        found, input = split_from_left(raw_input, #char "\n");
                        found, input = split_from_left(raw_input, #char "\r");
                        args := split(input, " ");
                        if args.count > 0 {
                            cmd := args[0];
                            args.data += 1;
                            args.count -= 1;
                            execute(cmd, args);
                        }
                    }
                case;
                    print_error_incorrect_argument_count(.[0]);
            }
        
        case "exit";
            if !interactive_mode {
                print("Error: cannot use `exit` outside of interactive prompt.\n");
                return;
            }
            interactive_mode = false;
        
        case "build";
            if args.count == {
                case 0;
                    if !working_directory_is_project() {
                        print("Error: current directory is not a jrc project.\n");
                        return;
                    }
                    build();
                case;
                    print_error_incorrect_argument_count(.[0]);
            }
        
        case "run";
            if args.count == {
                case 0;
                    if !working_directory_is_project() {
                        print("Error: current directory is not a jrc project.\n");
                        return;
                    }
                    bin := get_current_project_executable_name();
                    if !file_exists(bin) {
                        print("Error: % does not exist. Try building first.\n", bin);
                        return;
                    }
                    success := os_run_command(
                        bin,
                        working_directory=tprint("%/bin/", get_working_directory())
                    );
                case;
                    print_error_incorrect_argument_count(.[0]);
            }

        case;
            print("Error: invalid command \"%\".\n", cmd);
    }
}

message_loop :: () {
    while true {
        message := compiler_wait_for_message();
        if !message break;
        if message.kind == {
            case .COMPLETE;
            break;
        }
    }
}

print_command_prompt :: () {
    print("%> ", get_current_project_name());
}

print_error_incorrect_argument_count :: (expected: [] int = .[1]) #expand {
    assert(expected.count > 0);
    for expected assert(`args.count != it);
    expected_string: string;
    if expected.count == {
        case 1;
            expected_string = tprint("%", expected[0]);
        case 2;
            expected_string = tprint("% or %", expected[0], expected[1]);
        case;
            builder: String_Builder;
            for 0..expected.count-2 {
                print_to_builder(*builder, "%, ", expected[it]);
            }
            print_to_builder(*builder, "or %", expected[expected.count-1]);
            expected_string = builder_to_string(*builder);
    }
    print(ERROR_INCORRECT_ARGUMENT_COUNT, expected_string, `args.count);
}

working_directory_is_project :: () -> bool #must {
    return get_current_project_name() != "";
}

get_current_project_name :: () -> string {
    is_project := true;
    cwd := get_working_directory();
    path_overwrite_separators(cwd, #char "/");
    dir_name := slice(cwd, find_index_from_right(cwd, #char "/") + 1, 1024);
    is_project &= file_exists("main.jai");
    //TODO: some other condition, maybe an identifying file or manifest or...
    if is_project return dir_name;
    return "";
}

get_current_project_executable_name :: () -> string {
    builder: String_Builder;
    print_to_builder(*builder, "bin/");
    print_to_builder(*builder, get_current_project_name());
    #if OS == .WINDOWS {
        print_to_builder(*builder, ".exe");
    }
    return builder_to_string(*builder);
}

#run {
    defer print("\n");
    set_build_options_dc(.{do_output=false});

    args := compiler_get_command_line_arguments();

    if args.count == 0 {
        print(ERROR_ZERO_ARGUMENTS);
        return;
    }

    cwd := args[0];
    args.data += 1;
    args.count -= 1;

    if !set_working_directory(cwd) {
        print("Error: failed to set the current working directory to \"%\".\n", cwd);
        return;
    }

    if args.count == 0 {
        print(HELP);
    }
    else {
        cmd := args[0];
        args.data += 1;
        args.count -= 1;

        execute(cmd, args);
    }
}

interactive_mode := false;

#load "strings.jai";
#load "input.jai";

#import "String";
#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
