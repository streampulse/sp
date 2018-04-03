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

# check server files against sb files; upload new ones to sb ####

# metadata
meta_local = list.files(meta_folder, full.names=TRUE) #metadata filenames on server
sb_mdata_obj = item_get(sb_meta_id) # objects in metadata folder on sb

#get filenames in metadata folder on sb
insb_meta = vector()
for(i in 1:length(sb_mdata_obj$files)){
    insb_meta = append(insb_meta, sb_mdata_obj$files[[i]]$name)
}

#get filenames that need to be uploaded
to_upload_meta = vector()
for(i in 1:length(meta_local)){
    path_parts = strsplit(meta_local[i], '/')[[1]]
    fname = path_parts[length(path_parts)]
    if(! fname %in% insb_meta){
        to_upload_meta = append(to_upload_meta, meta_local[i])
    }
}

#chunk metadata upload vector into a list of vectors
working_item_id_meta = read('../logs_etc/working_sb_item_meta.txt')
nper = 10
chunks = split(to_upload_meta, ceiling(seq_along(to_upload_meta) / nper))

meta_loop_succeeded = FALSE
for(i in 1:length(chunks)){

    #try to upload chunk to current working item on sb
    systime = as.character(Sys.time()) #for logging and item name (if creating)
    metares = try(item_append_files(working_item_id_meta, chunks[[i]]))
    if(class(metares) == 'try-error'){

        #if that fails, try to create a new item, using datetime as name
        new_item = try(item_create(title=systime, parent_id=sb_meta_id))
        if(class(new_item) == 'try-error'){

            #server likey down
            write(paste('failed to create new meta item on', systime),
                '../logs_etc/sb_upload.log', append=TRUE)
            break
        } else {

            #if that succeeds, update file that tracks working id
            working_item_id_meta = new_item$id
            write(working_item_id_meta, '../logs_etc/working_sb_item_meta.txt')
            write(paste('created new meta item on', systime),
                '../logs_etc/sb_upload.log', append=TRUE)
        }

        #try to upload again
        metares = try(item_append_files(working_item_id_meta, chunks[[i]]))
        if(class(metares) == 'try-error'){

            #server must be down
            write(paste('meta upload failed after', i - 1, 'chunks on', systime),
                '../logs_etc/sb_upload.log', append=TRUE)
            break
        }
    }

    Sys.sleep(10)
    if(i == length(chunks)) meta_loop_succeeded = TRUE
}

if(meta_loop_succeeded){
    write(paste('meta upload succeeded after', i - 1, 'chunks on', systime),
        '../logs_etc/sb_upload.log', append=TRUE)
}



# data
data_local = list.files(data_folder, full.names=TRUE) #data filenames on server
sb_data_obj = item_get(sb_data_id) # objects in data folder on sb

#get filenames in data folder on sb
insb_data = vector()
for(i in 1:length(sb_data_obj$files)){
    insb_data = append(insb_data, sb_data_obj$files[[i]]$name)
}

#get filenames that need to be uploaded
to_upload_data = vector()
for(i in 1:length(data_local)){
    path_parts = strsplit(data_local[i], '/')[[1]]
    fname = path_parts[length(path_parts)]
    if(! fname %in% insb_data){
        to_upload_data = append(to_upload_data, data_local[i])
    }
}

#chunk data upload vector into a list of vectors
working_item_id_data = read('../logs_etc/working_sb_item_data.txt')
nper = 10
chunks = split(to_upload_data, ceiling(seq_along(to_upload_data)/nper))

data_loop_succeeded = FALSE
for(i in 1:length(chunks)){

    #try to upload chunk to current working item on sb
    systime = as.character(Sys.time()) #for logging and item name (if creating)
    datares = try(item_append_files(working_item_id_data, chunks[[i]]))
    if(class(datares) == 'try-error'){

        #if that fails, try to create a new item, using datetime as name
        new_item = try(item_create(title=systime, parent_id=sb_data_id))
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
        datares = try(item_append_files(working_item_id_data, chunks[[i]]))
        if(class(datares) == 'try-error'){

            #server must be down
            write(paste('data upload failed after', i - 1, 'chunks on', systime),
                '../logs_etc/sb_upload.log', append=TRUE)
            break
        }
    }

    Sys.sleep(10)
    if(i == length(chunks)) data_loop_succeeded = TRUE
}

if(data_loop_succeeded){
    write(paste('data upload succeeded after', i - 1, 'chunks on', systime),
        '../logs_etc/sb_upload.log', append=TRUE)
}
