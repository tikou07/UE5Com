% Build script for ZeroMQ C-MEX S-Functions

% Common settings
mex_flags = {'-g', '-output'}; % Use '-g' for debug symbols
third_party_dir = fullfile(pwd, 'ThirdParty');
include_dir = fullfile(third_party_dir, 'include');
lib_dir = fullfile(third_party_dir, 'lib', 'Win64');
zmq_lib = fullfile(lib_dir, 'libzmq-v143-mt-s-4_3_5.lib');
ws2_lib = 'ws2_32.lib';
iphlpapi_lib = 'iphlpapi.lib';

% Compiler flags for MSVC
cpp_flags = 'CXXFLAGS="$CXXFLAGS /std:c++17"';

% Include paths
include_path = ['-I"' include_dir '"'];

% Library paths and libraries to link
lib_path = ['-L"' lib_dir '"'];
libs = {zmq_lib, ws2_lib, iphlpapi_lib};

disp('--- Building C-MEX S-Functions ---');

% --- Build sfun_zeromq_image ---
disp('Building sfun_zeromq_image...');
if exist('sfun_zeromq_image', 'file')
    clear sfun_zeromq_image;
end
if exist('sfun_zeromq_image.mexw64', 'file')
    delete('sfun_zeromq_image.mexw64');
end
try
    mex(cpp_flags, mex_flags{:}, 'sfun_zeromq_image', fullfile('c_src', 'sfun_zeromq_image.cpp'), ...
        include_path, lib_path, libs{:});
    disp('sfun_zeromq_image build successful.');
    copyfile(fullfile(third_party_dir, 'bin', 'Win64', 'libzmq-mt-4_3_5.dll'), pwd);
catch e
    disp('Error building sfun_zeromq_image:');
    disp(e.message);
end

disp('--- Build process finished ---');
