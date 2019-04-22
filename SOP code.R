### R code for integrating and analyses of data files from SOP task
# SOP output files: 
#   e.g. "SopTaskID1iubit1.xls"
#   ID = 1,
#   condition = "iubit"
#   "1" = Pre measurement
###############################################################################################################

if (!require("pacman")) install.packages("pacman")
pacman::p_load("tidyverse", "rio", "psych", "ggplot2", "plyr")        

###############################################################################################################
#################### Read in all the .xls files and merge them ################################################
wd <- "E:/Cinetic idei noi/O.1.A SOP Data/TOATE excel redenumite"
setwd(wd)

## Read in the Data 

file_names <- dir(pattern = "\\.xls$")
## if above isn't good enough try the following:
# file_names <- list.files(wd)
# file_names <- sop_files[!file.info(sop_files)$isdir]   # exclude directories
# file_names <- sop_files[grep(".xls", sop_files, fixed = TRUE)]
names(file_names) <- basename(file_names)

Date <- plyr::ldply(file_names, rio::import)

## Data Munging

Date_Clean <- 
  Date %>%
    dplyr::rename(FileNames = 1) %>%                                                             # rename first column
    dplyr::mutate(TransFileNames = FileNames) %>%
    dplyr::select(FileNames, TransFileNames, everything()) %>%
    dplyr::mutate(TransFileNames = stringr::str_replace(TransFileNames, fixed(" "), "")) %>%     # remove white spaces
    dplyr::mutate(TransFileNames = stringr::str_replace(TransFileNames, ".xls", "")) %>%         # delete extension
    tidyr::separate(TransFileNames,                                                              # separate file name into variable names
                    into = c("Task", "ID", "Conditie", "PrePost"), 
                    sep = "(?=[A-Za-z])(?<=[0-9])|(?=[0-9])(?<=[A-Za-z])") %>%
    dplyr::mutate(PrePost = dplyr::recode(PrePost,                                               # recode 
                                          `1` = "Pre",
                                          `2` = "Post")) %>%
    dplyr::mutate_at(c("FileNames", "Task", "ID", "Conditie", "PrePost"), funs(factor(.))) %>%   # convert to factors
    dplyr::mutate(Conditie = forcats::fct_collapse(Conditie,                                     # collapse factor levels from typos
                                                   iubit = c("iubit", "iubita"), 
                                                   mama = c("mam", "mama"), 
                                                   prieten = c("prieten", "prietena"),
                                                   tata = "tata")) %>%
    select(-c("Task", "Subj_id", "Subj_age", "Gender", "Group", "TaskTime(minutes)"))            # keep only meaningful variable                                                               


Date_Trans <-  
  Date_Clean %>%
    dplyr::group_by(FileNames) %>%                                                               # by ID
    dplyr::mutate(Ones = sum(KeyName == 1, na.rm = TRUE),                                        # count button presses for One                    
                  Twos = sum(KeyName == 2, na.rm = TRUE),                                        # add na.rm because of empty rows in .xls
                  Threes = sum(KeyName == 3, na.rm = TRUE),
                  AllButtons = Ones + Twos + Threes) %>%                                         # total button presses                    
    dplyr::mutate(Ones45 = sum(KeyName == 1 & KeyTime < first(PointsTime), na.rm = TRUE),        # count button presses before 45s
                  Twos45 = sum(KeyName == 2 & KeyTime < first(PointsTime), na.rm = TRUE),
                  Threes45 = sum(KeyName == 3 & KeyTime < first(PointsTime), na.rm = TRUE),
                  AllButtons45 = Ones45 + Twos45 + Threes45) %>%                                 # total button presses before 45s
    dplyr::mutate(rOnes = Ones / AllButtons,                                                     # number of Ones relative to total presses
                  rTwos = Twos / AllButtons,                                        
                  rThrees = Threes / AllButtons,
                  rOnes45 = Ones45 / AllButtons45,        
                  rTwos45 = Twos45 / AllButtons45,
                  rThrees45 = Threes45 / AllButtons45) 
  
Date_Export <-                
  Date_Trans %>%
    dplyr::group_by(FileNames) %>%                                                               # by ID
    dplyr::filter(row_number() == 1)                                                             # first row contains all important information 

Date_Export %>%
    print(n = Inf)                                                                               # check the data

## Export Data (for merging with other datasets)

saveRDS(Date_Export, file = "O1a_Processed_SOP.RDS")

  
###############################################################################################################
############################################ Statistics #######################################################

# ## Independent Comparisons (eg for Ones) 
# # Plot indendent 
# ggplot(Date_Export, aes(x = PrePost, y = Ones)) +
#   geom_boxplot() +
#   facet_wrap(~Conditie) +
#   ggpubr::stat_compare_means(method = "t.test", paired = FALSE, comparisons = list(c("Pre","Post")))
# 
# # t test independent
# Date_Export %>% 
#   group_by(Conditie) %>% 
#   do(broom::tidy(t.test(.$Ones ~ .$PrePost, 
#                         mu = 0, 
#                         alt = "two.sided", 
#                         paired = FALSE, 
#                         conf.level = 0.95)))

## Paired Comparisons 
# Filter data for Paired Comparisons 
Date_Paired <- 
  Date_Export %>%
  mutate(PrePost = forcats::fct_relevel(PrePost, 'Pre', 'Post')) %>%               # change level order for plot
  group_by(ID, Conditie) %>%
  filter(n() != 1) %>%                                                             # exclude cases that dont have both Pre and Post data
  ungroup()

## Function for paired comparison plot
sop_paired_plot <- function(data, var, cond){
  var <- rlang::enquo(var)
  cond <- rlang::enquo(cond)
  ggplot(data, aes(x = !!cond, y = !!var)) +
    geom_boxplot() +
    stat_summary(fun.data = mean_se,  colour = "darkred") +
    xlab("") +
    facet_wrap(~Conditie) +
    ggpubr::stat_compare_means(method = "t.test", 
                               paired = TRUE, 
                               comparisons = list(c("Pre", "Post")))              # didn't include comparison list in func args
}

# Function t test paired
sop_paired_t <- function(data, var, cond){
  var <- deparse(substitute(var))
  cond <- deparse(substitute(cond))
  formula <- reformulate(cond, response = var)
  data %>%
    group_by(Conditie) %>%
    do(broom::tidy(t.test(data = ., formula,                                      # careful, this is a formula: var ~ PrePost
                          mu = 0,
                          alt = "two.sided",
                          paired = TRUE,
                          conf.level = 0.95)))
}

# Plots and t tests
sop_paired_plot(data = Date_Paired, var = Ones, cond = PrePost)                   # plot Ones 
sop_paired_t(data = Date_Paired, var = Ones, cond = PrePost)                      # t test Ones
sop_paired_plot(data = Date_Paired, var = Twos, cond = PrePost)
sop_paired_t(data = Date_Paired, var = Twos, cond = PrePost)
sop_paired_plot(data = Date_Paired, var = Threes, cond = PrePost)
sop_paired_t(data = Date_Paired, var = Threes, cond = PrePost)

sop_paired_plot(data = Date_Paired, var = Ones45, cond = PrePost)                 # plot Ones before 45s
sop_paired_t(data = Date_Paired, var = Ones45, cond = PrePost)                    # t test Ones before 45s
sop_paired_plot(data = Date_Paired, var = Twos45, cond = PrePost)
sop_paired_t(data = Date_Paired, var = Twos45, cond = PrePost)
sop_paired_plot(data = Date_Paired, var = Threes45, cond = PrePost)
sop_paired_t(data = Date_Paired, var = Threes45, cond = PrePost)

sop_paired_plot(data = Date_Paired, var = rOnes, cond = PrePost)                  # plot ratio Ones to total presses
sop_paired_t(data = Date_Paired, var = rOnes, cond = PrePost)                     # t test ratio Ones to total presses
sop_paired_plot(data = Date_Paired, var = rTwos, cond = PrePost)
sop_paired_t(data = Date_Paired, var = rTwos, cond = PrePost)
sop_paired_plot(data = Date_Paired, var = rThrees, cond = PrePost)
sop_paired_t(data = Date_Paired, var = rThrees, cond = PrePost)



###############################################################################################################
######################### TESTS -- DONT RUN ###################################################################
    # sop_files <- list.files(wd)    # we could have simplydone:  list.files(pattern = "\\.xls$")
    # # sop_files <- sop_files[!file.info(sop_files)$isdir]   # exclude directories
    # sop_files <- sop_files[grep(".xls", sop_files, fixed = TRUE)]
    # 
    # 
    # sop_files_df <- as.data.frame(sop_files) 
    # 
    # Date <- 
    #   sop_files_df %>%
    #   mutate(FileNames = sop_files) %>%
    #   select(FileNames, sop_files) %>%
    #   mutate(sop_files = stringr::str_replace(sop_files, fixed(" "), "")) %>%     # remove white spaces
    #   mutate(sop_files = stringr::str_replace(sop_files, ".xls", "")) %>%         # delete extension
    #   tidyr::separate(sop_files, 
    #                   into = c("Task", "ID", "Conditie", "PrePost"), 
    #                   sep = "(?=[A-Za-z])(?<=[0-9])|(?=[0-9])(?<=[A-Za-z])") 
