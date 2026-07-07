#!/bin/bash

backup_usage(){

        echo "Usage: ./backup.sh <path of source data> <path of backup folder>"

}
if [ $# -eq 0 ]; then
backup_usage
fi


source_dir=$1
destination_dir=$2
timestamp=$(date '+%Y-%m-%d-%H-%M-%S')

create_backup(){

        zip -r "${destination_dir}/backup_${timestamp}.zip" "${source_dir}" > /dev/null
        if [ $? -eq 0 ]; then
                echo "Backup successfull for ${timestamp}"
        fi

}

create_backup


perfrom_rotation(){

        backups=($(ls -t "${destination_dir}/backup_"*.zip 2>/dev/null))

  if [ ${#backups[@]} -gt 5 ]; then

          backupto_remove=("${backups[@]:5}")
            echo "${backupto_remove[@]}"

          for backup in "${backupto_remove[@]}"
          do
                  rm -r ${backup}
        done
  fi


}


perfrom_rotation