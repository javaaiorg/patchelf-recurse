#!/bin/bash -e

showUsage()
{
   cat <<EOF
Usage: $0 file|dir

EOF
}


autoPatchBinary()
{
	
	local binary="$1"
	local binary=${binary//\/\//\/}
	
	local rootPath="$2"
	local rootPath=${rootPath//\/\//\/}
	
	echo "Start analyze ELF binary: $binary" >&2

	
	
	#ldd ${binary} |awk '{if(substr($3,0,1)=="/") autoPatchBinary $3 $rootPath}'
	local deps=`ldd $binary |awk '{if(substr($3,0,1)=="/") printf "%s%s",$3,":"; else if(substr($1,0,1)=="/") printf "%s%s",$1,":";}'`
	
	local alldeps="${deps}"
	#echo $alldeps
	
	IFS=':'
	for dep in $alldeps
	do
		if [[ -z $dep ]];
		then
			#echo "continue"
			continue
		fi
		
		if [ -e "$dep" ];
		then
			
			local depbasename=`basename $dep`
			local lib=`printf "%s/%s" $rootPath $depbasename`
			
			if [ ! -e $lib ];
			then
				cp -n --copy-contents $dep $rootPath/lib
			else
				echo "lib not exists $lib"
			fi
		
			autoPatchBinary "$dep" "$rootPath"
		fi
		
		
	done
	unset IFS
	
	
	
}


autoPatchPath() {
	
	local pathParam="$1"
	local pathParam=${pathParam//\/\//\/}
	
	local rootPath="$2"
	local rootPath=${rootPath//\/\//\/}
	
	local libWrapperDir="$3"
	local libWrapperDir=${libWrapperDir//\/\//\/}
	
	#echo $pathParam $rootPath
	
	if [ -f "$pathParam" ] # If parameter is file, then patch the individual binary
	then
		
			
	
		local lddtest=`ldd ${pathParam} | grep "not a dynamic executable"`
		#echo "lddtest $lddtest"
		if [[ "$lddtest" != "" ]]
		then
			echo "${pathParam} is not a dynamic executable"
			:
		else
			autoPatchBinary "$pathParam" "$rootPath" 
			
			
			#local pathParamDir=`dirname ${pathParam}`
			#local rpathOfParamDir=`realpath -s --relative-to="${pathParamDir}" "$rootPath/lib/ld-linux-x86-64.so.2" `
			#local pathBaseName=`basename ${pathParam}`
			#local trySetInterp=`cd $pathParamDir && patchelf --set-interpreter "./${rpathOfParamDir}" ${pathBaseName}`
			
			
			# ld-linux-x86-64.so.2 ld-linux.so ld-2.17.so
			if [[ $pathParam == *"/ld"*".so"* ]]
			then 
				echo "skip */ld*.so*    ${pathParam}"
				:
			else 
				echo "patchelf ${pathParam}"
				local patchelfPath=`dirname $0`
				$patchelfPath/patchelf --set-rpath "\$ORIGIN/${libWrapperDir}lib" ${pathParam} || true
				printf "\n"
			fi
		fi
		
		unset lddtest
		
		
		
		:
	elif [ -d "$pathParam" ] # If parameter is a directory, then recursively look for ELF binaries and patch them
	then
		#echo "Patching all ELF binaries in directory: $1" >&2
		
		for childFile in $pathParam/*
		do
			local nextLevelLibWrapperDir="${libWrapperDir}"
			if [ -d $childFile ]
			then 
				nextLevelLibWrapperDir="${libWrapperDir}../"
			fi
			autoPatchPath "$childFile" "$rootPath" "${nextLevelLibWrapperDir}"
		done
	fi

}





patchLibs(){
	
	local libPath="$1"
	libPath=${libPath//\/\//\/}
	
	local rootPath="$2"
	local rootPath=${rootPath//\/\//\/}
	
	
	#echo $libPath 
	
	
	#echo "for start"
	
	for libfile in $libPath/*
	do
		
		if [[ $libfile == *"/ld"*".so"* ]]
		then 
			echo "skip */ld*.so*    ${libfile}"
			continue
			:
		fi
		
		if test -f $libfile
		then
			local lddtest=`ldd ${libfile} | grep "not a dynamic executable"`
			#echo "lddtest $lddtest"
			if [[ "$lddtest" != "" ]]
			then
				echo "${libfile} is not a dynamic executable"
				:
			else
				echo "patch lib: $libfile "
				#patchelf --set-interpreter "./ld-linux-x86-64.so.2" --set-rpath "\$ORIGIN/" ${libfile}
				local patchelfPath=`dirname $0`
				#echo "$patchelfPath/patchelf --set-rpath '\$ORIGIN/' ${libfile}"
				local rettemp=`$patchelfPath/patchelf --set-rpath '\$ORIGIN/' ${libfile}`
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
		
		mkdir -p "$inputRootPath/lib"
		autoPatchPath $inputPathParam $inputRootPath ""
		
		patchLibs "$inputRootPath/lib" "$inputRootPath"
		
		
	else
		echo $inputPathParam not exists.
		exit 1
	fi
	
fi





