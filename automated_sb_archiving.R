# library(devtools)
# install_github("USGS-R/sbtools")
library(sbtools)
library(sourcetools)
library(stringr)

# setwd('/home/mike/git/streampulse/server_copy/sp')
setwd('/home/aaron/sp')

#load sb credentials and local directory locations
conf = read_lines('config.py')
extract_from_config = function(key){
    ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
    val = str_match(conf[ind], '.*\\"(.*)\\"')[2]
    return(val)
}
sb_usr = extract_from_config('SB_USER')
sb_pass = extract_from_config('SB_PASS')
sb_meta_id = extract_from_config('SB_META')
sb_data_id = extract_from_config('SB_DATA')
meta_folder = extract_from_config('META_FOLDER')
data_folder = extract_from_config('UPLOAD_FOLDER')

#log in to sciencebase
authenticate_sb(sb_usr, sb_pass)
Sys.sleep(5)

# check server metadata files against sb metadata; upload new ones to sb ####

#get vector of metadata filenames on streampulse server
meta_local = list.files(meta_folder, full.names=TRUE)
# cat(paste(length(meta_local), 'metadata files on server.\n'))
write(paste(length(meta_local), 'metadata files on server.'),
    '../logs_etc/sb_upload.log', append=TRUE)

#get objects in metadata folder on sb
sb_meta_children = item_list_children(sb_meta_id, fields='id', limit=99999)
insb_meta = vector()
for(i in 1:length(sb_meta_children)){
    sb_meta_obj = item_get(sb_meta_children[[i]]$id)
    for(j in 1:length(sb_meta_obj$files)){
        insb_meta = append(insb_meta, sb_meta_obj$files[[j]]$name)
    }
}
# cat(paste(length(insb_meta), 'metadata files on SB.\n'))
write(paste(length(insb_local), 'metadata files on SB.'),
    '../logs_etc/sb_upload.log', append=TRUE)

#get filenames that need to be uploaded
to_upload_meta = vector()
for(i in 1:length(meta_local)){
    path_parts = strsplit(meta_local[i], '/')[[1]]
    fname = path_parts[length(path_parts)]
    if(! fname %in% insb_meta){
        to_upload_meta = append(to_upload_meta, meta_local[i])
    }
}
# cat(paste(length(to_upload_meta), 'metadata files to upload.\n'))
write(paste(length(to_upload_meta), 'metadata files to upload.'),
    '../logs_etc/sb_upload.log', append=TRUE)

#chunk metadata upload vector into a list of vectors
working_item_id_meta = read('../logs_etc/working_sb_item_meta.txt')
nper = 10
chunks = split(to_upload_meta, ceiling(seq_along(to_upload_meta) / nper))

meta_loop_succeeded = FALSE
if(length(to_upload_meta)){
    for(i in 1:length(chunks)){

        #try to upload chunk to current working item on sb
        systime = as.character(Sys.time()) #for logging and item name (if creating)
        metares = try(item_append_files(working_item_id_meta, chunks[[i]]),
            silent=TRUE)
        if(class(metares) == 'try-error'){

            #if that fails, try to create a new item, using datetime as name
            new_item = try(item_create(title=systime, parent_id=sb_meta_id),
                silent=TRUE)
            if(class(new_item) == 'try-error'){

                #server likey down
                write(paste('failed to create new meta item on', systime),
                    '../logs_etc/sb_upload.log', append=TRUE)
                break
            } else {

                #if creation succeeds, update file that tracks working id
                working_item_id_meta = new_item$id
                write(working_item_id_meta, '../logs_etc/working_sb_item_meta.txt')
                write(paste('created new meta item on', systime),
                    '../logs_etc/sb_upload.log', append=TRUE)
            }

            #try to upload again
            metares = try(item_append_files(working_item_id_meta, chunks[[i]]),
                silent=TRUE)
            if(class(metares) == 'try-error'){

                #server must be down
                write(paste('meta upload failed after', i - 1, 'chunks on', systime),
                    '../logs_etc/sb_upload.log', append=TRUE)
                break
            } else {
                # cat(paste('Uploaded', length(chunks[[i]]), 'files.\n'))
                write(paste('Uploaded', length(chunks[[i]]), 'files.'),
                    '../logs_etc/sb_upload.log', append=TRUE)
            }
        } else {
            # cat(paste('Uploaded', length(chunks[[i]]), 'files.\n'))
            write(paste('Uploaded', length(chunks[[i]]), 'files.'),
                '../logs_etc/sb_upload.log', append=TRUE)
        }


        Sys.sleep(10)
        if(i == length(chunks)) meta_loop_succeeded = TRUE
    }
}

if(meta_loop_succeeded){
    write(paste('meta upload succeeded after', i - 1, 'chunks on', systime),
        '../logs_etc/sb_upload.log', append=TRUE)
}


# check server data files against sb data files; upload new ones to sb ####

# get vector of data filenames on server
data_local = list.files(data_folder, full.names=TRUE) #data filenames on server
# cat(paste(length(data_local), 'data files on server.\n'))
write(paste(length(data_local), 'data files on server.'),
    '../logs_etc/sb_upload.log', append=TRUE)

#get objects in data folder on sb
sb_data_children = item_list_children(sb_data_id, fields='id', limit=99999)
insb_data = vector()
for(i in 1:length(sb_data_children)){
    sb_data_obj = item_get(sb_data_children[[i]]$id) # objects in data folder on sb
    for(j in 1:length(sb_data_obj$files)){
        insb_data = append(insb_data, sb_data_obj$files[[j]]$name)
    }
}
# cat(paste(length(insb_data), 'data files on SB.\n'))
write(paste(length(insb_data), 'data files on SB.'),
    '../logs_etc/sb_upload.log', append=TRUE)

#get filenames that need to be uploaded
to_upload_data = vector()
for(i in 1:length(data_local)){
    path_parts = strsplit(data_local[i], '/')[[1]]
    fname = path_parts[length(path_parts)]
    if(! fname %in% insb_data){
        to_upload_data = append(to_upload_data, data_local[i])
    }
}
# cat(paste(length(to_upload_data), 'data files to upload.\n'))
write(paste(length(to_upload_data), 'data files to upload.'),
    '../logs_etc/sb_upload.log', append=TRUE)

#chunk data upload vector into a list of vectors
working_item_id_data = read('../logs_etc/working_sb_item_data.txt')
nper = 10
chunks = split(to_upload_data, ceiling(seq_along(to_upload_data)/nper))

data_loop_succeeded = FALSE
if(length(to_upload_data)){
    for(i in 1:length(chunks)){

        #try to upload chunk to current working item on sb
        systime = as.character(Sys.time()) #for logging and item name (if creating)
        datares = try(item_append_files(working_item_id_data, chunks[[i]]),
            silent=TRUE)
        if(class(datares) == 'try-error'){

            #if that fails, try to create a new item, using datetime as name
            new_item = try(item_create(title=systime, parent_id=sb_data_id),
                silent=TRUE)
            if(class(new_item) == 'try-error'){

                #server likey down
                write(paste('failed to create new data item on', systime),
                    '../logs_etc/sb_upload.log', append=TRUE)
                break
            } else {

                #if that succeeds, update file that tracks working id
                working_item_id_data = new_item$id
                write(working_item_id_data, '../logs_etc/working_sb_item_data.txt')
                write(paste('created new data item on', systime),
                    '../logs_etc/sb_upload.log', append=TRUE)
            }

            #try to upload again
            datares = try(item_append_files(working_item_id_data, chunks[[i]]),
                silent=TRUE)
            if(class(datares) == 'try-error'){

                #server must be down
                write(paste('data upload failed after', i - 1, 'chunks on', systime),
                    '../logs_etc/sb_upload.log', append=TRUE)
                break
            } else {
                # cat(paste('Uploaded', length(chunks[[i]]), 'files.\n'))
                write(paste('Uploaded', length(chunks[[i]]), 'files.'),
                    '../logs_etc/sb_upload.log', append=TRUE)
            }
        } else {
            cat(paste('Uploaded', length(chunks[[i]]), 'files.\n'))
            write(paste('Uploaded', length(chunks[[i]]), 'files.'),
                '../logs_etc/sb_upload.log', append=TRUE)
        }

        Sys.sleep(10)
        if(i == length(chunks)) data_loop_succeeded = TRUE
    }
}

if(data_loop_succeeded){
    write(paste('data upload succeeded after', i - 1, 'chunks on', systime),
        '../logs_etc/sb_upload.log', append=TRUE)
}
