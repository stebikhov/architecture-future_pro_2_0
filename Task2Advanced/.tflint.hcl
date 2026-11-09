# Конфигурация TFLint для Task2Advanced (используется через --config в workflow).
#
# Рекомендованный пресет встроенного ruleset'а terraform плюс правила
# документации и стандартной структуры модуля: здесь они выполняются —
# все переменные и выходы описаны, каталог содержит main.tf, variables.tf,
# outputs.tf и README.md.
#
# Блоки rule обязаны быть на верхнем уровне файла: внутри plugin "terraform"
# их размещать нельзя, TFLint отвечает ошибкой «Blocks of type "rule" are not
# expected here».

config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}
