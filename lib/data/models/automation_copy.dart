import 'automation.dart';

extension AutomationCopy on Automation {
  Automation copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    Map<String, String>? parameters,
    List<AutomationStep>? steps,
    List<AutomationStep>? rollbackSteps,
    String? validation,
    String? outputParser,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Automation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      parameters: parameters ?? this.parameters,
      steps: steps ?? this.steps,
      rollbackSteps: rollbackSteps ?? this.rollbackSteps,
      validation: validation ?? this.validation,
      outputParser: outputParser ?? this.outputParser,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
