library(readr)
library(dplyr)
rm(list = ls())

setwd(dirname(rstudioapi::getSourceEditorContext()$path))
setwd("../Data")
getwd()



df <- read_csv2("1_solicitudes/1_solicitudes.csv", n_max = 10000)
    df <- df[order(df$num_solicitud_oferta, df$id_certificado_saldo), ]
    df <- df[order(df$id_consultante, df$id_certificado_saldo), ]

    aux <- (nrow(df) == length(unique(df$num_solicitud_oferta))) # is num_solicitud_oferta unique id by obs? 
    aux2 <- (nrow(df) == length(unique(df$id_certificado_saldo))) # is num_solicitud_oferta unique id by obs? 


print(summary(df$id_participe_ingreso))


    # find ids with >1 distinct certificado per consultante
    violations <- df %>%   group_by(id_consultante) %>%   summarise(n_cert = n_distinct(id_certificado_saldo)) %>%   filter(n_cert > 1)
    violations # some consultantes have more than one certificado.

    # id_consultante: individual id, id_certificado_saldo: not sure. I do not understand why 

    violations <- df %>%   group_by(num_solicitud_oferta) %>%   summarise(n_cert = n_distinct(periodo_solicitud)) %>%  filter(n_cert > 1)
    violations # for a given num_solicitud_oferta the periodo_solicitud is unique.

##################

df2 <- read_csv2("2_ofertas_muestra_acep/2_ofertas_sample_acep.csv", n_max = 100000)

    df2 <- df2[order(df2$id_participe, df2$id_oferta), ]
    aux <- (nrow(df2) == length(unique(df2$id_oferta))) # id_oferta is not unique identifier. 


    # restrict the sample to decrease heterogeneity 
    df2 <- df2 %>% filter(tipo_pension == "PE")
    df2 <- df2 %>% filter(cod_modalidad_pension == 1)
    df2 <- df2 %>%  select(-tipo_pension, -cod_modalidad_pension)   
    print(nrow(df2)) # 10000 obs.

    #  check that there are only annuities (not RV diferida, nor RV inmediata with retiro programado)
    print(table(df2$ind_oferta_rta_vit_inmediata, useNA = "ifany"))
    print(table(df2$ind_oferta_rta_vit_diferida, useNA = "ifany"))
    print(table(df2$ind_oferta_rta_vit_inm_r_pro, useNA = "ifany"))
    df2 <- df2 %>% select(-starts_with("ind_oferta_rta_vit"))



    print(table(df2$sec_beneficiario, useNA = "ifany")) # only zeros 
    print(table(df2$num_meses_diferidos, useNA = "ifany")) # only zeros 
    df2 <- df2 %>%  select(-sec_beneficiario, -num_meses_diferidos)   

###### 
   
df3 <- read_csv2("2_ofertas_muestra_sol/2_ofertas_sample_sol.csv", n_max = 10000)
 

    # restrict the sample to decrease heterogeneity 
    df3 <- df3 %>% filter(tipo_pension == "PE")
    df3 <- df3 %>% filter(cod_modalidad_pension == 1)
    df3 <- df3 %>%  select(-tipo_pension, -cod_modalidad_pension)   
    print(nrow(df3)) # around a third of n_max. 

    #  check that there are only annuities (not RV diferida, nor RV inmediata with retiro programado)
    print(table(df3$ind_oferta_rta_vit_inmediata, useNA = "ifany"))
    print(table(df3$ind_oferta_rta_vit_diferida, useNA = "ifany"))
    print(table(df3$ind_oferta_rta_vit_inm_r_pro, useNA = "ifany"))
    df3 <- df3 %>% select(-starts_with("ind_oferta_rta_vit")) #here already reduced to a fourth of the original size.


####

N_max <- 10e5 

df4 <- read_csv2("2_ofertas/2_ofertas.csv", n_max = N_max)

    # restrict the sample to decrease heterogeneity 
    df4 <- df4 %>% filter(tipo_pension == "PE", cod_modalidad_pension == 1)
   
    #  check that there are only annuities (not RV diferida, nor RV inmediata with retiro programado)
    print(table(df4$ind_oferta_rta_vit_inmediata, useNA = "ifany"))
    print(table(df4$ind_oferta_rta_vit_diferida, useNA = "ifany"))
    print(table(df4$ind_oferta_rta_vit_inm_r_pro, useNA = "ifany"))
    print(table(df4$num_meses_diferidos, useNA = "ifany"))
    print(table(df4$num_anos_diferidos, useNA = "ifany"))
   
    df4 <- df4 %>% select(-tipo_pension, -cod_modalidad_pension,
                             -starts_with("ind_oferta_rta_vit"), -starts_with("num_")) 

######### 

start <- Sys.time()
N_max <- 1e5                           # 1 million rows
path  <- "2_ofertas/2_ofertas.csv"



df4 <- read_csv2(path, n_max = N_max) %>%
  filter(tipo_pension == "PE",
         cod_modalidad_pension == 1) %>%
 

df4 <- read_csv2(path, n_max = N_max) %>%
  filter(tipo_pension == "PE",
         cod_modalidad_pension == 1) %>%
  select(-tipo_pension,
         -cod_modalidad_pension,
         -starts_with("ind_oferta_rta_vit"),
         -starts_with("num_"))

total_rows <- length(count.fields(path, sep = ";")) - 1   # subtract header
n_chunks   <- ceiling(total_rows / N_max) # 1406
n_chunks <- 5 
for (j in seq(2, n_chunks)) {
    j <- 2 
  skip_rows <- (j - 1) * N_max
  df_aux <- read_csv2(path, skip = skip_rows, n_max = N_max) %>%
    filter(tipo_pension == "PE",
           cod_modalidad_pension == 1) %>%
    select(-tipo_pension,
           -cod_modalidad_pension,
           -starts_with("ind_oferta_rta_vit"),
           -starts_with("num_"))
  df4 <- bind_rows(df4, df_aux)
}

print(paste("Total rows after binding:", nrow(df4)))
write_csv2(df4, "df4.csv")

end   <- Sys.time()
print(end - start)





total_rows <- length(count.fields("2_ofertas/2_ofertas.csv", sep = ";")) - 1   # subtract header


 for (j in 2:100){ 
    initial_row <- (j - 1) * N_max
    


    df_aux <- read_csv2(path, skip = skip_rows, n_max = N_max) %>%
            filter(tipo_pension == "PE",
                cod_modalidad_pension == 1) %>%
            select(-tipo_pension,
                -cod_modalidad_pension,
                -starts_with("ind_oferta_rta_vit"),
                -starts_with("num_"))




    df4 <- bind_rows(df4, df_aux)
}










df4$val_uf_pension <- as.numeric(df4$val_uf_pension)
print(summary(df4$val_uf_pension))

    vars_to_keep <- c("id_oferta", "id_certificado_saldo", "periodo_ingreso", "val_uf_pension")  # replace with the actual variable names

    df4 <- df4 %>% select(all_of(vars_to_keep))









    






# dplyr approach
aux <- df2 %>%
  group_by(id_oferta) %>%
  filter(n() > 1)

aux <- df2[df2$id_participe == "02122069", ]
View(aux) 

  # find ids with >1 distinct certificado per consultante
    violations <- df %>%   group_by(id_consultante) %>%   summarise(n_cert = n_distinct(id_certificado_saldo)) %>%   filter(n_cert > 1)
    violations # some consultantes have more than one certificado.







    vars_to_keep <- c("id_participe", "id_oferta")  # replace with the actual variable names

    df2 <- df2 %>% select(all_of(vars_to_keep))

    violations <- df %>%   group_by(num_solicitud_oferta) %>%   summarise(n_cert = n_distinct(periodo_solicitud)) %>%  filter(n_cert > 1)




data <- read_csv2( "3_aceptaciones/3_aceptaciones.csv", n_max = 1000)

data2 <- read_csv2("2_ofertas_muestra_sol/2_ofertas_sample_sol.csv", n_max = 1000)


############# 
# is var x unique id by obs? 
aux <- (nrow(df) == length(unique(df$x)))

# 
print(table(df$x, useNA = "ifany"))

attr(df$your_var, "label") <- "This is my variable label"

# keep only x1, x2 in df 

    vars_to_keep <- c("id_participe", "id_oferta")  # replace with the actual variable names

    df2 <- df2 %>% select(all_of(vars_to_keep))



print(names(df))