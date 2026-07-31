// Workflow templates - simplified stub
import 'package:flutter/material.dart';
import 'package:xiaosu/core/workflow/workflow_engine.dart';

class WorkflowTemplateInfo {
  final String name;
  final String description;
  final IconData icon;
  final Workflow Function() builder;
  
  const WorkflowTemplateInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.builder,
  });
}

class WorkflowTemplates {
  static List<WorkflowTemplateInfo> get catalog => [];
}
