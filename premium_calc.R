load_data <- function(file_path = "ssa_2023.csv") {
  data <- read.csv(file_path)
  colnames(data) <- c("age", "male_qx", "male_lx", "male_ex", "female_qx", "female_lx", "female_ex")
  data$age       <- as.numeric(data$age)                     
  data$male_qx   <- as.numeric(data$male_qx)
  data$female_qx <- as.numeric(data$female_qx)
  data$male_ex   <- as.numeric(data$male_ex)
  data$female_ex <- as.numeric(data$female_ex)
  data$male_lx   <- as.numeric(gsub(",", "", data$male_lx))
  data$female_lx <- as.numeric(gsub(",", "", data$female_lx))
  return(data)
}

sex_select <- function(data, sex) {
    if (sex == "Male") {
    list(x = data$age,
        qx = data$male_qx,
        lx = data$male_lx)
    } else {
    list(x = data$age,
        qx = data$female_qx,
        lx = data$female_lx)
    }
}

whole_life_premium <- function(life_table, age, face, interest){
    v <- 1/(1 + interest)
    start <- age + 1
    benefitPV <- 0
    premiumPV <- 0
    for(i in start:(length(life_table$x))){
        k <- i - start
        survival <- life_table$lx[i] / life_table$lx[start]
        deathProb <- survival * life_table$qx[i]
        benefitPV <- benefitPV + face * deathProb * v^(k+1)
        premiumPV <- premiumPV + survival * v^k
    }
    return(round(benefitPV / premiumPV, 2))
}

n_term_premium <- function(life_table, age, face, interest, term){
    v <- 1/(1 + interest)
    start <- age + 1
    benefitPV <- 0
    premiumPV <- 0
    for(i in start:min(start + term - 1, length(life_table$x))){
        k <- i - start
        survival <- life_table$lx[i] / life_table$lx[start]
        deathProb <- survival * life_table$qx[i]
        benefitPV <- benefitPV + face * deathProb * v^(k+1)
        premiumPV <- premiumPV + survival * v^k
    }
    return(round(benefitPV / premiumPV, 2))
}

# all in one
compute_apv <- function(life_table, age, face, interest, type, term) {
    v <- 1 / (1 + interest)
    start <- age + 1
    n <- length(life_table$x)
    if (start > n) {
        return(list(ins_factor = NULL, benefit_pv = NULL, annuity_pv = NULL, level_premium = NULL))
    }
    benefitPV <- 0
    premiumPV <- 0
    end <- if (type == "Whole life") n else min(start + term - 1, n)
    for (i in start:end) {
        k <- i - start
        survival <- life_table$lx[i] / life_table$lx[start]
        deathProb <- survival * life_table$qx[i]
        benefitPV <- benefitPV + face * deathProb * v^(k+1)
        premiumPV <- premiumPV + survival * v^k
    }
  level_premium <- if (premiumPV > 0) benefitPV / premiumPV else NULL

  return(list(
    ins_factor = round(benefitPV/face, 6),
    benefit_pv = round(benefitPV, 2),
    annuity_pv = round(premiumPV, 4),
    level_premium = round(level_premium, 2)
  ))
}

reserve_at_t <- function(life_table, age, t, face, interest, type, term, P) {
    current_age <- age + t
    v <- 1 / (1 + interest)
    start <- current_age + 1
    n <- length(life_table$x)
    if (type == "Term") {
        remaining <- term - t
        if (remaining <= 0) return(0)
        end <- min(start + remaining - 1, n)
    } else {
    end <- n
    }
    if (start > n) return(0)
    benefitPV <- 0
    premiumPV <- 0
    for (i in start:end) {
        k <- i - start
        survival <- life_table$lx[i] / life_table$lx[start]
        deathProb <- survival * life_table$qx[i]
        benefitPV <- benefitPV + face * deathProb * v^(k+1)
        premiumPV <- premiumPV + survival * v^k
    }
    return(round(benefitPV - P * premiumPV, 2))
}

compute_reserves <- function(life_table, age, face, interest, type, term = 20) {
    apv <- compute_apv(life_table, age, face, interest, type, term)
    P   <- apv$level_premium
    n   <- length(life_table$x)
    max_t <- if (type == "Whole life") {
        min(50, n - age - 1)
    } else {
    term
    }
    max_t <- max(max_t, 0)
    ts <- 0:max_t
    reserves <- sapply(ts, function(t) reserve_at_t(life_table, age, t, face, interest, type, term, P))
    return(data.frame(
        duration = ts,
        age = age + ts,
        reserve = reserves,
        pct_face = round(reserves/face * 100, 2)
    ))
}