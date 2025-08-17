# pak::pak("kbenoit/ellmer@fix/628-robust-parallel_chat_structured")
library(ellmer)

# load criminal offense descriptions across three PA counties
# skip pre-processing to maintain real-world applicability
crimes <- read.csv("crimes.csv")

# load UCCS offense categories and types
toc <- openxlsx::readWorkbook("cjars_toc.xlsx", sheet = 3)

toc_offense_category <- toc |>
  dplyr::distinct(charge_desc) |>
  dplyr::mutate(charge_desc = tolower(charge_desc)) |>
  dplyr::pull(charge_desc)

toc_offense_type <- toc |>
  dplyr::distinct(offense_type_desc) |>
  dplyr::mutate(offense_type_desc = tolower(offense_type_desc)) |>
  dplyr::pull(offense_type_desc)

# create ellmer chat object
chat <- chat("openai/gpt-5-mini-2025-08-07",
  system_prompt = "You are classifying criminal offense descriptions"
)

# define schema to get structured data from model
schema <- type_object(
  # offense category (UCCS)
  offense_category = type_enum(
    toc_offense_category,
    "The primary offense category"
  ),
  # offense type (UCCS)
  offense_type = type_enum(
    toc_offense_type,
    "The primary crime type.
    If violent and another type clearly applies, choose violent."
  ),
  # harm level and type (UK's Office for National Statistics)
  harm_level = type_enum(
    c(
      "individual",
      "community",
      "institutional",
      "societal"
    ),
    "The primary harm level"
  ),
  harm_type = type_enum(
    c(
      "physical",
      "emotional or psychological",
      "financial or economic",
      "community safety",
      "privacy"
    ),
    "The primary harm type"
  ),
  # harm score (custom)
  harm_score = type_number(
    "A score for representing that this offense creates obvious harm,
    not just a harmless social norm violation because it's illegal,
    ranging from 0.0 to 1.0."
  ),
  # action type (UCCS)
  action_type = type_enum(
    c(
      "occured",
      "attempted",
      "conspiracy"
    ),
    "The action type was labeled as conspiracy or attempted, or the act probabily occured"
  ),
  # model uncertainty (custom)
  uncertainty_score = type_number(
    "Your uncertainty in the classification responses and scores,
    higher scores reflect unclear or difficult to classify descriptions,
    ranging from 0.0 to 1.0."
  )
)

response <- parallel_chat_structured_robust(
  chat,
  prompts = as.list(crimes$description),
  type = schema,
  include_status = TRUE,
  on_error = "continue"
)

utils::write.csv(
  response |>
    dplyr::mutate(
      description = crimes |> dplyr::pull(description)
    ) |>
    dplyr::select(-status),
  "schema_openai_test.csv",
  row.names = FALSE
)
