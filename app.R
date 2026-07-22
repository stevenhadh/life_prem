library(shiny)
library(ggplot2)
 
source("premium_calc.R")
ssa <- load_data("ssa_2023.csv")
 
ui <- fluidPage(
  titlePanel("Life Insurance Pricing and Reserves"),
  sidebarLayout(
    sidebarPanel(
      selectInput("type", "Type of policy: ",
                  c("Whole life" = "Whole life", "Term" = "Term")),
      uiOutput("term_input"),
      sliderInput("age", "Age: ",
                  min = 18, max = 85, value = 35, step = 1),
      radioButtons("sex", "Sex: ",
                   c("Male" = "Male", "Female" = "Female")),
      numericInput("face", "Coverage amount: ",
                  min = 10000, max = 10000000, value = 500000, step = 1000),
      sliderInput("interest", "Interest rate (%): ",
                  min = 0, max = 10, value = 4, step = 0.1)
    ),
 
    mainPanel(
      tabsetPanel(id = "tabs",
        tabPanel(title = "Pricing",
          h3("Annual Level Premium"),
          h2(textOutput("premiumText"), style = "color:royalblue"),
          br(),
          h4("Actuarial Present Values"),
          tableOutput("apvTable"),
          h5("Methodology"),
          tags$ul(
            tags$li("Net premium only: no profit loading"),
            tags$li("Equivalence principle: EPV(premiums) = EPV(benefits) at issue"),
            tags$li("Death benefit paid at end of year of death"),
            tags$li("Premiums paid at start of each policy year"),
            tags$li("Source: SSA 2023 Period Life Table"),
          )
        ),
        tabPanel(title = "Analysis",
        h4("Premium vs. Age"),
        plotOutput("agePlot"),
        h4("Premium vs. Interest"),
        plotOutput("interestPlot"),
        h4("Premium vs. Sex"),
        plotOutput("sexPlot")
        ),
        tabPanel(title = "Reserves",
          h4("Reserve Development"),
          plotOutput("reservePlot"),
          h4("Reserve Table"),
          tableOutput("reserveTable")
        )
      )
    )
  )
)
 
server <- function(input, output) {
  # term input
  output$term_input <- renderUI({
    if (input$type == "Term") {
      numericInput("term", "Length of term in years: ",
                   min = 5, max = 120, value = 20)
    }
  })

  # premium output
  output$premiumText <- renderText({
    req(input$face, input$age, input$interest)
    validate(
      need(is.numeric(input$face) && input$face >= 10000,
           "Please enter a coverage amount of at least $10,000.")
    )
    life <- sex_select(ssa, input$sex)
    i <- input$interest / 100
    premium <- if (input$type == "Whole life") {
      whole_life_premium(life, input$age, input$face, i)
    } else {
      n_term_premium(life, input$age, input$face, i, input$term)
    }
    paste0("$", format(premium, big.mark = ",", nsmall = 2))
  })
  
  # apv table
  output$apvTable <- renderTable({
    life <- sex_select(ssa, input$sex)
    i <- input$interest / 100
    d <- compute_apv(life, input$age, input$face, i, input$type, input$term)
    ins <- if (input$type == "Whole life") "A_x" else paste0("A1_x:", input$term)
    ann <- if (input$type == "Whole life") "a_x"  else paste0("a_x:", input$term)
    data.frame(
      Symbol = c(ins, "NSP", ann, "P"),
      Description = c(
        "EPV of $1 death benefit",
        "Net Single Premium ",
        "EPV of $1/yr annuity-due",
        "Level Annual Net Premium"
      ),
      Value = c(
        d$ins_factor,
        paste0("$", format(d$benefit_pv, big.mark = ",", nsmall = 2)),
        d$annuity_pv,
        paste0("$", format(d$level_premium, big.mark = ",", nsmall = 2))
      )
    )
  })

  # age plot
  output$agePlot <- renderPlot({
    life <- sex_select(ssa, input$sex)
    i <- input$interest / 100
    ages <- 18:85
    prem <- sapply(ages, function(age) compute_apv(life, age, input$face, i, input$type, input$term)$level_premium)
    df <- data.frame(Age = ages, Premium = prem)
    ggplot(df, aes(x = Age, y = Premium)) +
      geom_ribbon(aes(ymin = 0, ymax = Premium), fill = "lightblue") +
      geom_line(color = "blue") +
      geom_vline(xintercept = input$age, color = "red") +
      annotate("text", x = input$age - 4, y = max(df$Premium, na.rm = TRUE), label = paste("Age =", input$age), color = "red") +
      scale_y_continuous(labels = scales::dollar_format()) +
      labs(x = "Issue Age", y = "Annual Premium ($)")
  })

  # interest plot
  output$interestPlot <- renderPlot({
    life <- sex_select(ssa, input$sex)
    rates <- seq(0.5, 10, by = 0.25)
    prem <- sapply(rates, function(i) compute_apv(life, input$age, input$face, i/100, input$type, input$term)$level_premium)
    df <- data.frame(Rate = rates, Premium = prem)
    ggplot(df, aes(x = Rate, y = Premium)) +
      geom_ribbon(aes(ymin = 0, ymax = Premium), fill = "lightgreen", alpha = 0.5) +
      geom_line(color = "darkgreen") +
      geom_vline(xintercept = input$interest, color = "red") +
      annotate("text", x = input$interest - 0.5, y = max(df$Premium, na.rm = TRUE), label = paste("i =", input$interest, "%"), color = "red") +
      scale_y_continuous(labels = scales::dollar_format()) +
      labs(x = "Interest Rate (%)", y = "Annual Premium ($)")
  })

  # sex plot
  output$sexPlot <- renderPlot({
    life_m <- sex_select(ssa, "Male")
    life_f <- sex_select(ssa, "Female")
    i <- input$interest / 100
    ages <- 18:85
    prem_m <- sapply(ages, function(age) (compute_apv(life_m, age, input$face, i, input$type, input$term))$level_premium)
    prem_f <- sapply(ages, function(age) (compute_apv(life_f, age, input$face, i, input$type, input$term))$level_premium)
    df <- data.frame(Age = rep(ages, 2), Premium = c(prem_m, prem_f), Sex  = rep(c("Male", "Female"), each = length(ages)))
    ggplot(df, aes(x = Age, y = Premium, color = Sex)) +
          geom_line() +
          scale_color_manual(values = c("Male" = "blue", "Female" = "red")) +
          scale_y_continuous(labels = scales::dollar_format()) +
          labs(x = "Issue Age", y = "Annual Premium ($)")
  })

  # reserve plot
  output$reservePlot <- renderPlot({
    life <- sex_select(ssa, input$sex)
    i <- input$interest / 100
    df <- compute_reserves(life, input$age, input$face, i, input$type, input$term)
    ggplot(df, aes(x = duration, y = reserve)) +
      geom_area(fill = "lightblue") +
      geom_line(color = "blue") +
      scale_y_continuous(labels = scales::dollar_format()) +
      labs(x = "Policy Duration (years)", y = "Prospective Reserve ($)")
  })

  # reserve table
  output$reserveTable <- renderTable({
    life <- sex_select(ssa, input$sex)
    i <- input$interest / 100
    df <- compute_reserves(life, input$age, input$face, i, input$type, input$term)
    data.frame(
      "Duration (t)" = df$duration,
      "Age" = df$age,
      "Prospective Reserve" = sapply(df$reserve, function(x) paste0("$", format(x, big.mark = ",", nsmall = 2))),
      "% of Face Amount" = paste0(formatC(df$pct_face, format = "f", digits = 2), "%"),
      check.names = FALSE,
      stringsAsFactors = FALSE)
  })
}
 
shinyApp(ui = ui, server = server)