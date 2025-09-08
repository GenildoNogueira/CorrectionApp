# AI Answer Sheet Corrector

This is a Flutter project that implements an application for automatically correcting exam answer sheets. The app uses the device's camera to capture an image of the answer sheet, processes the image with OpenCV to detect marked answers, and compares them with a pre-configured answer key to generate results.

## Features

- **Exam Configuration**: Define exam name, number of questions, and number of alternatives per question (A, B, C, D, E).
- **Official Answer Key Creation**: Register the correct answers for each question.
- **Automatic Correction via Camera**: Take a photo of the student's answer sheet.
- **Image Processing with OpenCV**: The app detects the sheet, corrects perspective, and identifies filled answer bubbles.
- **AI-Powered Answer Extraction**: A robust algorithm analyzes contours and fill patterns to determine the marked alternative.
- **Manual Correction**: Allows manual input or adjustment of answers.
- **Results Visualization**: Displays the number of correct answers, errors, and percentage score.
- **Gallery Import**: Select an answer sheet image directly from your device's gallery.

## How It Works (The AI Process)

1. **Preprocessing**: The image is converted to grayscale and an adaptive threshold filter is applied to handle lighting variations.
2. **Contour Detection**: The largest contour in the image is identified, assumed to be the answer sheet.
3. **Perspective Correction**: The sheet image is "flattened" (four-point perspective transform) to remove angle distortions.
4. **Alternative Detection**: The algorithm finds all circular contours (answer bubbles) in the flattened image.
5. **Fill Analysis**: For each question, the app measures the amount of black pixels in each alternative bubble to determine which was most filled, considering it as the marked answer.
6. **Result Generation**: The extracted answers are compared with the official answer key.

## Technologies Used

- Flutter & Dart
- OpenCV (through the `opencv_dart` library) for image processing
- `camera` for device camera integration
- `image_picker` for importing images from gallery

## Main Screens

- **ConfigurationScreen**: Where the teacher configures the exam and official answer key.
- **CorrectionScreen**: The main screen where the magic happens. The user can capture the image, see the student's answer sheet being filled (automatically or manually), and check the final result.

## Getting Started

```bash
# 1. Clone the repository
git clone <YOUR_REPOSITORY_URL>
cd project-name

# 2. Install dependencies
flutter pub get

# 3. Run the application
flutter run
```

## Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- A physical device or emulator with camera support

## Dependencies

The main dependencies used in this project include:

- `flutter/material.dart` - UI framework
- `opencv_dart` - Computer vision and image processing
- `camera` - Camera functionality
- `image_picker` - Gallery image selection
- Other standard Flutter packages for UI and functionality

## Installation

1. Ensure you have Flutter installed on your system
2. Clone this repository
3. Navigate to the project directory
4. Run `flutter pub get` to install all dependencies
5. Connect a device or start an emulator
6. Run `flutter run` to launch the application

## Usage

1. **Configure Exam**: Start by setting up your exam parameters (number of questions, alternatives per question)
2. **Create Answer Key**: Input the correct answers for each question
3. **Capture Answer Sheet**: Use the camera to take a photo of the student's completed answer sheet
4. **AI Processing**: The app automatically processes the image and extracts the marked answers
5. **Review Results**: Check the correction results and make manual adjustments if needed
6. **View Score**: See the final score and detailed results

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

If you encounter any issues or have questions, please open an issue in the repository.
