# Конфигурация TFLint (используется через --config в workflow).
#
# Базовый набор — рекомендованный пресет встроенного ruleset'а terraform
# (то же, что TFLint применяет по умолчанию, но явно).
#
# Правила о документировании переменных и выходов здесь не включены осознанно:
# часть переменных окружений — служебная, а описания вынесены в модуль
# (modules/vm/variables.tf). Правило terraform_standard_module_structure входит в
# пресет recommended и включён по умолчанию
# (main.tf, variables.tf, outputs.tf есть и в modules/vm, и в envs/*).
# эти правила включены явно в Task2Advanced/.tflint.hcl.

config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
