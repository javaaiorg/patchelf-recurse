#!/bin/bash -e

showUsage()
{
   cat <<EOF
Usage: $0 file|dir

EOF
}




autoPatchPath() {
	
	local pathParam="$1"
	pathParam=${pathParam//\/\//\/}
	
	local absRootPath="$2"
	absRootPath=${absRootPath//\/\//\/}
	
	#echo $pathParam $absRootPath
	
	if [ -f "$pathParam" ] # If parameter is file, then patch the individual binary
	then
		
			
	
		local lddtest=`ldd ${pathParam} | grep "not a dynamic executable"`
		#echo "lddtest $lddtest"
		if [[ "$lddtest" != "" ]]
		then
			echo "${pathParam} is not a dynamic executable"
		else
			
			echo "patchelf ${pathParam}"
			#local rettemp=`patchelf --set-interpreter "$absRootPath/lib/ld-linux-x86-64.so.2" ${libfile}`
			#local rettemp=`patchelf --replace-needed /lib64/ld-linux-x86-64.so.2 "\$ORIGIN/lib/ld-linux-x86-64.so.2" ${pathParam}`
			local patchelfPath=`dirname $0`
			local rettemp=`$patchelfPath/patchelf --set-interpreter ${absRootPath}/lib/ld-linux-x86-64.so.2 ${pathParam}`
			printf "\n"
		fi
		
		unset lddtest
		
	elif [ -d "$pathParam" ] # If parameter is a directory, then recursively look for ELF binaries and patch them
	then
		#echo "Patching all ELF binaries in directory: $1" >&2
		
		for childFile in $pathParam/*
		do
			autoPatchPath "$childFile" "$absRootPath"
		done
	fi

}





patchLibs(){
	
	local libPath="$1"
	libPath=${libPath//\/\//\/}
	
	local absRootPath="$2"
	absRootPath=${absRootPath//\/\//\/}
	
	#echo $libPath 
	
	
	#echo "for start"
	
	for libfile in $libPath/*
	do
		
		if test -f $libfile
		then
			local lddtest=`ldd ${libfile} | grep "not a dynamic executable"`
			#echo "lddtest $lddtest"
			if [[ "$lddtest" != "" ]]
			then
				#echo "${libfile} is not a dynamic executable"
				:
			else
				echo "javaai.org patch lib: $libfile "
				#local rettemp=`patchelf --replace-needed "$absRootPath/lib/ld-linux-x86-64.so.2" ${libfile}`
				#local rettemp=`patchelf --set-interpreter "$absRootPath/lib/ld-linux-x86-64.so.2" ${libfile}`
				#local rettemp=`patchelf --replace-needed /lib64/ld-linux-x86-64.so.2 "\$ORIGIN/lib/ld-linux-x86-64.so.2" ${libfile}`
				local patchelfPath=`dirname $0`
				local rettemp=`$patchelfPath/patchelf --set-interpreter $absRootPath/lib/ld-linux-x86-64.so.2 ${libfile}`
			fi
		fi
	done


}






inputPathParam="$1"


# Execute operations
if [[ -z $inputPathParam ]];
then
	echo inputPathParam is empty.
	showUsage
	exit 1
else
	if [ -e "$inputPathParam" ]
	then
		
		inputRootPath=$inputPathParam
		if test -f $inputPathParam
		then
			inputRootPath=$(dirname $inputPathParam)
		fi
		
		inputRootPath=`realpath $inputRootPath`
		
		mkdir -p "$inputRootPath/lib"
		autoPatchPath $inputPathParam $inputRootPath
		
		patchLibs "$inputRootPath/lib" $inputRootPath
		
		
	else
		echo $inputPathParam not exists.
		exit 1
	fi
	
fi





