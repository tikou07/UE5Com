% run_build.m
% This script is a wrapper to execute the main build script with error handling.
% It is intended to be called from the command line.
try
    build_mex_files;
catch e
    fprintf(2, '%s\n', e.getReport('extended'));
    exit(1);
end
exit(0);
