## Charge librairies
library(dplyr)
library(forcats)

## Function to read files
read.files <- function(filepat1,path,fun, encoding = "latin1") {
  filenames <- list.files(path = path, pattern = filepat1, recursive = TRUE, full.names = TRUE)
  sapply(filenames, fun, simplify = F)
  
}

# 1. Read files
dhs <-read.files( ".*GNPR.*\\.DTA", DataDir, read_dta) ### Indivdual file
dhs = list(dhs[[3]], dhs[[4]]) # 2012 and 2018 files
dhs <- lapply(dhs, subset, hv103 == 1) #  Persons who stayed in the household the night before the survey

dhs_hhs = read.files(".*GNHR.*\\.DTA", DataDir, read_dta) ## Household file

dhs_hhs = dhs_hhs[[4]] ### 2018
#2. Select the variables 
hh_ex = dhs_hhs %>%
  dplyr::select(hv000, hhid, hv001, hv002, hv003, hv012, hv024, hv025, hv005, hv021, hv022, hv106_01, hv115_01, hv220, contains("hml10_"), hv227, hml1, hv014, hv216, hv013, hv270, hv219, hv216)


#3. Calculate Insecticide-treated net (Number of ITN in household, (If only ITN take account, otherwise take hml1 only))
hh_ex$nommiimenage = rowSums(hh_ex[c("hml10_1", "hml10_2", "hml10_3", "hml10_4", "hml10_5", "hml10_6",
                                     "hml10_7")], na.rm = TRUE)


### remove households with no members (hv013>0)

hh_ex = subset(hh_ex, hv013 > 0)

#4.Recode the variables to be included in the analysis of risk factors for ITN ownership

hh_ex = hh_ex %>% dplyr::mutate(urb = ifelse(hv025 == 1, "0", "1"),
                                hh_size=ifelse(hv013 >= 1 & hv013 <=4, '1-4', 
                                               ifelse(hv013 >4 & hv013<=7, '5-7', ifelse(hv013 >=8, '>8', ''))),
                                rooms = ifelse(hv216 <=3, "1-3", ifelse(hv216 >=4 & hv216<=6, "4-6", ifelse(hv216>=7, "> 6", ''))),
                                Num_childre = ifelse(hv014 >0, 1, 0),
                                sex = ifelse(hv219 == 1, 0, 1),
                                wealth = case_when(hv270 == 1 ~ "lowest",
                                                   hv270 == 2 ~ "second", hv270 == 3 ~ "Middle", hv270 == 4 ~ "Fourth",
                                                   hv270 == 5 ~ "Highest"),
                                Edu =case_when(hv106_01 == 0 ~ "None", hv106_01 == 1 ~ "primary",
                                               hv106_01 == 2 | hv106_01 == 3 ~ "High", hv106_01 == 8 ~ "dont know"),
                                head_age = cut(hv220, c(15, 30, 40, 50, 60, 98), include.lowest = T, righ = T))


#5. Reorder the levels of the variables
### Household siz, Number of rooms, Presence of children, sex of household head, wealth quintile, level of education of hh head,Age of household head
cols = c('urb', 'hh_size', 'rooms', 'Num_childre', 'sex', 'wealth', 'Edu', 'head_age')

hh_ex[cols] <- lapply(hh_ex[cols], factor)

hh_ex$hh_size = relevel(hh_ex$hh_size, ref = "1-4")
hh_ex$rooms = relevel(hh_ex$rooms, ref = "1-3")
hh_ex$sex = relevel(hh_ex$sex, ref = "0")
level_order= c("1", "2", "3", "4", "5")
hh_ex$wealth = mapvalues(hh_ex$wealth, from = c("lowest", "second", "Middle", "Fourth", "Highest"),
                         to = c("1", "2", "3", "4", "5"))
hh_ex$wealth = relevel(hh_ex$wealth, ref = "1")
hh_ex$head_age = relevel(hh_ex$head_age, ref = "(40,50]")
hh_ex$Edu = mapvalues(hh_ex$Edu, from = c("None", "primary", "High", "dont know"),
                      to = c("0", "1", "2", "3"))

hh_ex$Edu = relevel(hh_ex$Edu, ref = "0")

#6. Calcul indicators for household level (Proportion of HH with at least one ITN)

hh_ex = hh_ex %>%
  dplyr::mutate(HH_at_least_one = ifelse(nommiimenage >0, 1, 0)) %>%
  dplyr::mutate(numerateur = hv013/nommiimenage)%>%
  dplyr::mutate(ratio_HH_2 = ifelse(numerateur <=2, 1, 0)) %>%
  dplyr::mutate(Potential_users = nommiimenage*2)

write.csv(hh_ex, '/Users/ousmanediallo/Box/NU-malaria-team/data/guinea_dhs/data_analysis/master/data/data_PR/data_HR.csv')


#7. Select the variables in the household file to merge it with the individual data file
hh_2018 = hh_ex %>%
  #dplyr::mutate(numnet = hml1) %>%
  #dplyr::filter(hh_has_itn == 1) %>%
  dplyr::select(hhid, nommiimenage, HH_at_least_one, ratio_HH_2)


#8. Merge PR file and HR (hh_2018)
dhs_PR = dhs[[2]] ## Individual file

data_PR_HR = merge(dhs_PR, hh_2018, by = "hhid")

#8.  Calculate the different indicators in the individual file
data_PR_HR = data_PR_HR %>%
  ## Potential ITN users in hh potuse
  dplyr::mutate(potuse = nommiimenage*2)%>%
  dplyr::mutate(defacto_pop = hv013) %>%
  dplyr::mutate(potuse_ajusted = ifelse(potuse > defacto_pop, defacto_pop, potuse))%>%
  group_by(hhid) %>%
  dplyr::arrange(hhid) %>%
  #dplyr::mutate(n_with_access = pmin(nommiimenage*2, stay))%>%
  dplyr::mutate(access=potuse_ajusted/defacto_pop) %>%
  dplyr::mutate(indi = defacto_pop - potuse_ajusted) %>%
  dplyr::mutate(net_use =ifelse(hml12 %in% c(1,2),"1", "0" )) %>%
  dplyr::arrange(hhid,net_use) %>%
  dplyr::mutate(access2 =c(rep(0, unique(indi)),rep(1, unique(potuse_ajusted)))) %>%
  dplyr::mutate(access3 = ifelse(access2=="0" & net_use == "1", "1", ifelse(access2 == "1" & net_use == "1", "1", ifelse(access2 == "0" & net_use== "0", "0", 
                                                                                                                         ifelse(access2=='1' & net_use == '0', '1',''))))) %>%
  ## Intra-household ITN ownership
  dplyr::mutate(net_use_among_access = ifelse(access3 == 1 & net_use == 1, 1, 0)) %>%
  ### Proportion of HHs with at least one ITN for every 2 persons (any net)
  dplyr::mutate(saturation = ifelse(hml1 > 0 & ratio_HH_2 == 1, 1, 0))

write.csv(data_PR_HR, '/Users/ousmanediallo/Box/NU-malaria-team/data/guinea_dhs/data_analysis/master/data/data_PR/data_PR_HR.csv')