-- This is the relative path to where compiled data will land.
COMPILE_DIR = "../local/compiled_data/"
-- This is the relative path to where intermediate data (source data) is taken from.
HASHED_DIR = "../local/intermediate_data/"
PACKAGE_ID = 0

if family == "windows" then
	-- The JIT_EXE is used for the compilers that are based on lua.
	JIT_EXE = "../local/release/win32/luajit.exe"
	-- Load the dll / dynamic library that exposes the BuildEngineFileID-function
	-- This dll should expose all lua-functions that the build script requires
	-- from the engine.
	LoadPlugin("../local/release/win32/resource_dyn")
else
	error("Platform not supported yet")
end

-- Simple copy-compiler.
-- This adds it as a job.
function CopyFile(input, output)
	local outputs = {}

	local copy_command = "cp"
	local copy_append = ""
	
	if family == "windows" then
		copy_command = "copy /b" -- binary copy
		copy_append = " >nul 2>&1" -- suppress output
	end

	local srcfile = input
	local dstfile = output
	if family == "windows" then
		srcfile = str_replace(srcfile, "/", "\\")
		dstfile = str_replace(dstfile, "/", "\\")
	end
	
	AddJob( output,
			"copy " .. input .. " -> " .. output,
			copy_command .. " " .. srcfile .. " " .. dstfile .. copy_append )
			
	-- make sure that the files timestamps are updated correctly
	SetTouch(output)
	AddDependency(output, input)
	table.insert(outputs, output)

	return outputs
end

-- Simple move-file-compiler in case you have a compiler that requires multiple steps
-- and needs files to be moved around.
-- This adds a job.
function MoveFile(input, output)
	local outputs = {}

	local move_command = "mv"
	
	if family == "windows" then
		move_command = "move " -- binary copy
	end

	local srcfile = input
	local dstfile = output
	if family == "windows" then
		srcfile = str_replace(srcfile, "/", "\\")
		dstfile = str_replace(dstfile, "/", "\\")
	end
	
	AddJob( output,
			"move " .. input .. " -> " .. output,
			move_command .. " " .. srcfile .. " " .. dstfile )
			
	-- make sure that the files timestamps are updated correctly
	SetTouch(output)
	AddDependency(output, input)
	table.insert(outputs, output)

	return outputs
end

-- Uses the nvdxt-compiler located in the ./compilers/-folder relative to your build system.
-- Moves the compiled texture to the compiled-data folder.
function CompileTextures(config, ...)
	for filename,_ in TableWalk({...}) do
		local no_src_file        = string.gsub(filename, "source_data/", "")
		local intermed_base_file = COMPILE_DIR .. no_src_file
		local hash_file          = HASHED_DIR .. BuildEngineFileID(PACKAGE_ID, type_ids.RESOURCE_TYPE_TEXTURE, no_src_file )
		--CopyFile(filename, hash_file)
		AddJob(hash_file .. ".dds",
			"texture compiler " .. filename .. " -> " .. hash_file,
			"compilers\\nvdxt.exe" .. " -file " .. filename .. " -outfile " .. hash_file .. " -u8888 -nomipmap")
		MoveFile(hash_file .. ".dds", hash_file)
	end
end

-- Example on how you just want to copy a file.
function CompileConfigs(config, ...)
	for filename,_ in TableWalk({...}) do
		local no_src_file        = string.gsub(filename, "source_data/", "")
		local intermed_base_file = COMPILE_DIR .. no_src_file
		local hash_file          = HASHED_DIR .. BuildEngineFileID(PACKAGE_ID, type_ids.RESOURCE_TYPE_CONFIG, no_src_file )
		CopyFile(filename, hash_file)
	end
end

-- This compilation step uses a compiler build in lua to compile your resource packages into binary format.
function CompileResourcePackages(config, ...)
	for filename, _ in TableWalk( { ... } ) do
		local no_src_file = string.gsub(filename, "source_data/", "")
		local intermed_base_file = COMPILE_DIR .. no_src_file
		local hash_file = HASHED_DIR .. BuildEngineFileID(PACKAGE_ID, type_ids.RESOURCE_TYPE_RESOURCE_PACKAGE, no_src_file )
		AddJob(hash_file,
					"resource_package_compiler " .. filename .. " -> " .. hash_file,
					JIT_EXE .. " .\\compilers\\resource_package_compiler.lua " .. filename .. " " .. hash_file)
		SetTouch(hash_file)
		AddDependency( hash_file, filename )
		AddDependency( hash_file, "compilers/resource_package_compiler.lua")
	end
end

-- Start output of file-resource-mappings.
CompileTextures(config, CollectRecursive("source_data/textures/*.dds"))
CompileConfigs(config, CollectRecursive("source_data/surfaces/*.config"))
CompileResourcePackages(config, CollectRecursive("source_data/resource_packages/*.package"))