# Basic Genkit Dart Test Application

This directory contains a basic test application for the Genkit Dart package.

## Running the Application

To run the application, you can use the provided shell script. Before running the script, you need to make sure the dependencies for both the Dart server and the Node.js runner are installed.

### Prerequisites

1.  **Install Dart dependencies**:

    ```bash
    dart pub get
    ```

2.  **Install Node.js dependencies**:

    Navigate to the `node_server` directory and install the required npm packages:

    ```bash
    cd node_server
    npm install
    ```

### Start the Server

Once the dependencies are installed, you can run the server using the `run_with_gemini_cli.sh` script:

```bash
./tool/run_with_gemini_cli.sh
```

This will start the Genkit development server, which runs the Dart application.
