// Kafka Connect API Client
// Provides methods to interact with Kafka Connect REST API

export class KafkaConnectClient {
  constructor(baseUrl, connectorClass = null) {
    this.baseUrl = baseUrl;
    this.connectorClass = connectorClass;
  }

  async request(path, options = {}) {
    const url = `${this.baseUrl}${path}`;
    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        }
      });

      if (!response.ok) {
        const error = await response.json().catch(() => ({ message: response.statusText }));
        throw new Error(`HTTP ${response.status}: ${error.message || JSON.stringify(error)}`);
      }

      return await response.json();
    } catch (error) {
      throw new Error(`Failed to fetch ${path}: ${error.message}`);
    }
  }

  // Get all connectors
  async listConnectors() {
    return await this.request('/connectors');
  }

  // Get connector info
  async getConnector(name) {
    return await this.request(`/connectors/${name}`);
  }

  // Get connector status
  async getConnectorStatus(name) {
    return await this.request(`/connectors/${name}/status`);
  }

  // Get connector config
  async getConnectorConfig(name) {
    return await this.request(`/connectors/${name}/config`);
  }

  // Create or update connector
  async createOrUpdateConnector(name, config) {
    return await this.request(`/connectors/${name}/config`, {
      method: 'PUT',
      body: JSON.stringify(config)
    });
  }

  // Delete connector
  async deleteConnector(name) {
    return await this.request(`/connectors/${name}`, {
      method: 'DELETE'
    });
  }

  // Restart connector
  async restartConnector(name) {
    return await this.request(`/connectors/${name}/restart`, {
      method: 'POST'
    });
  }

  // Pause connector
  async pauseConnector(name) {
    return await this.request(`/connectors/${name}/pause`, {
      method: 'PUT'
    });
  }

  // Resume connector
  async resumeConnector(name) {
    return await this.request(`/connectors/${name}/resume`, {
      method: 'PUT'
    });
  }

  // Get connector tasks
  async getConnectorTasks(name) {
    return await this.request(`/connectors/${name}/tasks`);
  }

  // Restart connector task
  async restartTask(connectorName, taskId) {
    return await this.request(`/connectors/${connectorName}/tasks/${taskId}/restart`, {
      method: 'POST'
    });
  }

  // Get all connectors with their statuses (filtered for ClickHouse connectors only)
  async getAllConnectorsStatus() {
    const connectors = await this.listConnectors();
    const statuses = await Promise.all(
      connectors.map(async (name) => {
        try {
          const [status, config] = await Promise.all([
            this.getConnectorStatus(name),
            this.getConnectorConfig(name)
          ]);

          // Filter by connector class if specified
          if (this.connectorClass) {
            if (config['connector.class'] === this.connectorClass) {
              return { name, ...status, config };
            }
            return null;
          }
          
          // No filter - return all connectors
          return { name, ...status, config };
        } catch (error) {
          return null;
        }
      })
    );

    // Filter out null values (filtered connectors and errors)
    return statuses.filter(s => s !== null);
  }

  // Get connector metrics/details
  async getConnectorDetails(name) {
    try {
      const [info, status, config, tasks] = await Promise.all([
        this.getConnector(name),
        this.getConnectorStatus(name),
        this.getConnectorConfig(name),
        this.getConnectorTasks(name)
      ]);

      return {
        name,
        info,
        status,
        config,
        tasks
      };
    } catch (error) {
      throw new Error(`Failed to get connector details: ${error.message}`);
    }
  }
}
